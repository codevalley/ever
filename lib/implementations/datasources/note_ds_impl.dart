import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/logging.dart';
import '../../domain/core/circuit_breaker.dart';
import '../../domain/core/events.dart';
import '../../domain/core/local_cache.dart';
import '../../domain/core/retry_config.dart';
import '../../domain/core/retry_events.dart';
import '../../domain/events/note_events.dart';
import '../../domain/datasources/note_ds.dart';
import '../../domain/entities/note.dart';
import '../config/api_config.dart';
import '../models/note_model.dart';

/// Implementation of NoteDataSource using HTTP and local cache
class NoteDataSourceImpl implements NoteDataSource {
  final http.Client client;
  final LocalCache cache;
  final RetryConfig retryConfig;
  final CircuitBreakerConfig circuitBreakerConfig;
  final String Function() getAccessToken;
  
  final _eventController = StreamController<DomainEvent>.broadcast();

  NoteDataSourceImpl({
    required this.client,
    required this.cache,
    required this.retryConfig,
    required this.circuitBreakerConfig,
    required this.getAccessToken,
  });

  String get accessToken => getAccessToken();

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  Future<void> initialize() async {
    await cache.initialize();
  }

  @override
  void dispose() {
    _eventController.close();
  }

  @override
  bool isOperationSupported(String operation) {
    // All operations are supported
    return true;
  }

  /// Execute an operation with retry logic
  Future<T> _executeWithRetry<T>(
    String operation,
    Future<T> Function() apiCall,
  ) async {
    var attempts = 0;
    final startTime = DateTime.now();
    while (true) {
      try {
        attempts++;
        iprint('Attempt $attempts executing $operation', '🔄');
        return await apiCall();
      } catch (e) {
        final elapsed = DateTime.now().difference(startTime);
        wprint('$operation failed after ${elapsed.inMilliseconds}ms: $e');
        
        if (!retryConfig.shouldRetry(e) || attempts >= retryConfig.maxAttempts) {
          if (attempts > 1) {
            eprint('$operation failed after $attempts attempts', '❌');
            _eventController.add(RetryExhausted(operation, e, attempts));
          }
          rethrow;
        }
        
        final delay = retryConfig.getDelayForAttempt(attempts);
        iprint('Waiting ${delay.inMilliseconds}ms before attempt ${attempts + 1}', '⏳');
        _eventController.add(RetryAttempt(operation, attempts, delay, e));
        await Future.delayed(delay);
      }
    }
  }

  @override
  Stream<List<Note>> list({Map<String, dynamic>? filters}) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.note.list));
    var attempts = 0;

    try {
      final response = await _executeWithRetry(
        ApiConfig.operations.note.list,
        () async {
          attempts++;
          var url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.note.list}');
          if (filters != null && filters.isNotEmpty) {
            url = url.replace(queryParameters: filters.map((k, v) => MapEntry(k, v.toString())));
          }
          
          iprint('API Request: GET $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          
          final response = await client.get(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
          );

          print('\n=== API Response ===');
          print('Status Code: ${response.statusCode}');
          final responseBody = response.body;
          print('Response Length: ${responseBody.length}');
          print('Raw Response: $responseBody');
          print('=== End Response ===\n');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              print('\n=== Response Data Type ===');
              print('responseData type: ${responseData.runtimeType}');
              print('=== End Type Info ===\n');

              if (responseData is! Map<String, dynamic>) {
                throw Exception('Expected response to be a Map, got ${responseData.runtimeType}');
              }

              final data = responseData['data'];
              print('\n=== Data Field Type ===');
              print('data type: ${data.runtimeType}');
              print('data value: $data');
              print('=== End Data Info ===\n');

              if (data is! Map<String, dynamic>) {
                throw Exception('Expected data to be a Map, got ${data.runtimeType}');
              }

              final items = data['items'];
              print('\n=== Items Field Type ===');
              print('items type: ${items.runtimeType}');
              print('items value: $items');
              print('=== End Items Info ===\n');

              if (items is! List) {
                throw Exception('Expected items to be a List, got ${items.runtimeType}');
              }
              
              // Map each item to a Note model
              final notes = <NoteModel>[];
              for (final item in items) {
                print('\n=== Processing Item ===');
                print('item type: ${item.runtimeType}');
                print('item value: $item');
                
                if (item is! Map<String, dynamic>) {
                  throw Exception('Expected item to be a Map, got ${item.runtimeType}');
                }

                try {
                  final note = NoteModel.fromJson(item);
                  print('Successfully created note: $note');
                  notes.add(note);
                } catch (e, s) {
                  print('Failed to create note from item: $e\n$s');
                  rethrow;
                }
              }
              print('=== End Processing ===\n');
              
              if (attempts > 1) {
                _eventController.add(RetrySuccess(ApiConfig.operations.note.list, attempts));
              }
              
              _eventController.add(OperationSuccess(ApiConfig.operations.note.list, notes));
              _eventController.add(NotesRetrieved(notes));
              
              yield notes;
              return response;
            } catch (e, s) {
              print('JSON parsing error: $e\n$s');
              throw Exception('Invalid response format from server: $e');
            }
          } else {
            String error;
            try {
              final responseData = json.decode(response.body) as Map<String, dynamic>;
              error = responseData['error'] ?? responseData['message'] ?? 'Unknown error';
            } catch (e) {
              error = 'Failed to parse error message: ${response.body}';
            }
            
            if (response.statusCode >= 500) {
              throw http.ClientException('Service unavailable');
            }
            throw Exception(error);
          }
        },
      );

      try {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final data = responseData['data'] as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>;
        
        // Map each item to a Note model
        final notes = items.map((item) {
          final rawItem = item as Map<String, dynamic>;
          final note = NoteModel.fromJson({
            'id': rawItem['id'],
            'content': rawItem['content'],
            'user_id': rawItem['user_id'],
            'attachments': rawItem['attachments'] ?? [],
            'processing_status': rawItem['processing_status'],
            'enrichment_data': rawItem['enrichment_data'],
            'processed_at': rawItem['processed_at'],
            'created_at': rawItem['created_at'],
            'updated_at': rawItem['updated_at'],
          });
          print('Parsed note: ${note.toString()}');
          return note;
        }).toList();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.note.list, attempts));
        }
        
        _eventController.add(OperationSuccess(ApiConfig.operations.note.list, notes));
        _eventController.add(NotesRetrieved(notes));
        
        yield notes;
      } catch (e, s) {
        print('Error processing response: $e\n$s');
        throw Exception('Failed to process server response: $e');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.note.list,
        e.toString(),
      ));
      rethrow;
    }
  }
} 