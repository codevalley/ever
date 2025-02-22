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

  // Cache key constants
  static const _noteCachePrefix = 'note:';
  static const _noteListCacheKey = 'note:list';

  NoteDataSourceImpl({
    required this.client,
    required this.cache,
    required this.retryConfig,
    required this.circuitBreakerConfig,
    required this.getAccessToken,
  });

  String get accessToken => getAccessToken();

  String _getNoteKey(String noteId) => '$_noteCachePrefix$noteId';


  @override
  Stream<DomainEvent> get events => _eventController.stream;

  // Add initialization flag
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    await cache.initialize();
    _isInitialized = true;
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

  /// Execute a Future operation with retry logic
  Future<T> _executeWithRetryFuture<T>(
    String operation,
    Future<T> Function() apiCall,
  ) async {
    var attempts = 0;
    final startTime = DateTime.now();
    
    // Add a small delay before first attempt to ensure connection is ready
    if (!_isInitialized) {
      await Future.delayed(Duration(milliseconds: 100));
      _isInitialized = true;
    }

    while (true) {
      try {
        attempts++;
        iprint('Attempt $attempts executing $operation', '🔄');
        
        // For first attempt, ensure connection is ready
        if (attempts == 1) {
          try {
            final testUrl = Uri.parse('${ApiConfig.apiBaseUrl}/health');
            await client.get(
              testUrl, 
              headers: ApiConfig.headers.withAuth(accessToken)
            ).timeout(Duration(seconds: 2));
          } catch (e) {
            // If health check fails, throw a retriable error
            throw http.ClientException('Connection not ready');
          }
        }
        
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
  Stream<Note> create(Note note) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.note.create));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.note.create,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.note.create}');
          final model = NoteModel.forCreation(
            content: note.content,
            userId: note.userId,
          );
          final body = json.encode(model.toJson());
          
          iprint('API Request: POST $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          iprint('Request Body: $body', '📦');
          
          final response = await client.post(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
            body: body,
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 201) {
            return response;
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
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

      final responseData = json.decode(response.body);
      final data = responseData['data'];
      final createdNote = NoteModel.fromJson(data).toDomain();
      
      // Cache the newly created note
      await cache.set(_getNoteKey(createdNote.id), data);
      // Invalidate list cache since we have a new note
      await cache.remove(_noteListCacheKey);
      
      if (attempts > 1) {
        _eventController.add(RetrySuccess(ApiConfig.operations.note.create, attempts));
      }
      
      _eventController.add(OperationSuccess(ApiConfig.operations.note.create, createdNote));
      _eventController.add(NoteCreated(createdNote));
      
      yield createdNote;
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.note.create,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Stream<Note> update(Note note) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.note.update));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.note.update,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.note.note(note.id)}');
          final model = NoteModel(
            id: int.parse(note.id),

            content: note.content,
            userId: note.userId,
            createdAt: note.createdAt,
            updatedAt: DateTime.now(),
            attachments: [], // TODO: Handle attachments
            processingStatus: ProcessingStatus.pending,
            enrichmentData: {},
          );
          final body = json.encode(model.toJson());
          
          iprint('API Request: PUT $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          iprint('Request Body: $body', '📦');
          
          final response = await client.put(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
            body: body,
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              throw Exception('Invalid response format from server');
            }
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
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
        final responseData = json.decode(response.body);
        final data = responseData['data'];
        final updatedNote = NoteModel.fromJson(data).toDomain();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.note.update, attempts));
        }
        
        _eventController.add(OperationSuccess(ApiConfig.operations.note.update, updatedNote));
        _eventController.add(NoteUpdated(updatedNote));
        
        yield updatedNote;
      } catch (e) {
        throw Exception('Failed to process server response: ${e.toString()}');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.note.update,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Stream<String> delete(String id) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.note.delete));
    var attempts = 0;
    final startTime = DateTime.now();

    while (true) {
      try {
        attempts++;
        iprint('Attempt $attempts executing delete note', '🔄');
        
        final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.note.note(id)}');
        
        iprint('API Request: DELETE $url', '🌐');
        iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
        
        final response = await client.delete(
          url,
          headers: ApiConfig.headers.withAuth(accessToken),
        );

        iprint('API Response Status: ${response.statusCode}', '📥');
        iprint('Response Body: ${response.body}', '📦');

        if (response.statusCode == 204 || response.statusCode == 200) {
          if (attempts > 1) {
            _eventController.add(RetrySuccess(ApiConfig.operations.note.delete, attempts));
          }
          
          // Clear cache for the deleted note
          await cache.remove(_getNoteKey(id));
          // Invalidate list cache since we deleted a note
          await cache.remove(_noteListCacheKey);
          
          _eventController.add(OperationSuccess(ApiConfig.operations.note.delete));
          _eventController.add(NoteDeleted(id));
          
          yield id;
          return;
        } else {
          String error;
          try {
            error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
          } catch (e) {
            error = 'Failed to parse error message: ${response.body}';
          }
          
          if (response.statusCode >= 500) {
            throw http.ClientException('Service unavailable');
          }
          throw Exception(error);
        }
      } catch (e) {
        final elapsed = DateTime.now().difference(startTime);
        wprint('delete_note failed after ${elapsed.inMilliseconds}ms: $e');
        
        if (!retryConfig.shouldRetry(e) || attempts >= retryConfig.maxAttempts) {
          if (attempts > 1) {
            eprint('delete_note failed after $attempts attempts', '❌');
            _eventController.add(RetryExhausted(ApiConfig.operations.note.delete, e, attempts));
          }
          _eventController.add(OperationFailure(
            ApiConfig.operations.note.delete,
            e.toString(),
          ));
          rethrow;
        }
        
        final delay = retryConfig.getDelayForAttempt(attempts);
        iprint('Waiting ${delay.inMilliseconds}ms before attempt ${attempts + 1}', '⏳');
        _eventController.add(RetryAttempt(ApiConfig.operations.note.delete, attempts, delay, e));
        await Future.delayed(delay);
      }
    }
  }

  @override
  Stream<List<Note>> list({Map<String, dynamic>? filters}) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.note.list));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
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

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              throw Exception('Invalid response format from server');
            }
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
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
        final responseData = json.decode(response.body);
        final data = responseData['data'] as Map<String, dynamic>;
        final items = data['items'] as List;
        final notes = items.map((item) => NoteModel.fromJson(item).toDomain()).toList();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.note.list, attempts));
        }
        
        _eventController.add(OperationSuccess(ApiConfig.operations.note.list, notes));
        _eventController.add(NotesRetrieved(notes));
        
        yield notes;
      } catch (e) {
        throw Exception('Failed to process server response: ${e.toString()}');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.note.list,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Stream<Note> read(String id) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.note.read));
    final cacheKey = _getNoteKey(id);
    
    try {
      // Log cache operation
      iprint('Clearing cache for key: $cacheKey', '🗑️');
      
      // Clear cache and wait for completion
      await cache.remove(cacheKey);
      
      // Verify cache is cleared
      final cachedData = await cache.get(cacheKey);
      if (cachedData != null) {
        wprint('Cache not properly cleared for key: $cacheKey', '⚠️');
      }

      // Fetch fresh data
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.note.read,
        () async {
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.note.note(id)}');
          
          iprint('API Request: GET $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          
          final response = await client.get(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            return response;
          } else if (response.statusCode == 404) {
            throw Exception('Note not found');
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
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

      final responseData = json.decode(response.body);
      final data = responseData['data'];
      final note = NoteModel.fromJson(data).toDomain();
      
      // Validate fetched note matches requested ID
      if (note.id != id) {
        throw Exception('Server returned incorrect note');
      }
      
      // Store in cache
      iprint('Storing note in cache with key: $cacheKey', '💾');
      await cache.set(cacheKey, data);
      
      _eventController.add(OperationSuccess(ApiConfig.operations.note.read, note));
      _eventController.add(NoteRetrieved(note));
      
      yield note;
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.note.read,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Future<List<Note>> search(String query) async {
    _eventController.add(OperationInProgress(ApiConfig.operations.note.search));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.note.search,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.note.list}')
              .replace(queryParameters: {'q': query});
          
          iprint('API Request: GET $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          
          final response = await client.get(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              throw Exception('Invalid response format from server');
            }
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
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
        final responseData = json.decode(response.body);
        final dataList = responseData['data'] as List;
        final notes = dataList.map((data) => NoteModel.fromJson(data).toDomain()).toList();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.note.search, attempts));
        }
        
        _eventController.add(OperationSuccess(ApiConfig.operations.note.search, notes));
        
        return notes;
      } catch (e) {
        throw Exception('Failed to process server response: ${e.toString()}');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.note.search,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Future<Note> process(String noteId) async {
    _eventController.add(OperationInProgress(ApiConfig.operations.note.process));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.note.process,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.note.process(noteId)}');
          
          iprint('API Request: POST $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          
          final response = await client.post(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              throw Exception('Invalid response format from server');
            }
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
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
        final responseData = json.decode(response.body);
        final data = responseData['data'];
        final note = NoteModel.fromJson(data).toDomain();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.note.process, attempts));
        }
        
        _eventController.add(OperationSuccess(ApiConfig.operations.note.process, note));
        _eventController.add(NoteProcessingCompleted(note));
        
        return note;
      } catch (e) {
        throw Exception('Failed to process server response: ${e.toString()}');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.note.process,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Future<Note> addAttachment(String noteId, Attachment attachment) async {
    _eventController.add(OperationInProgress(ApiConfig.operations.note.addAttachment));
    var attempts = 0;

    try {
      final response = await _executeWithRetryFuture(
        ApiConfig.operations.note.addAttachment,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.note.attachment(noteId)}');
          final body = json.encode({
            'type': attachment.type,
            'url': attachment.url,
          });
          
          iprint('API Request: POST $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.withAuth(accessToken)}', '📤');
          iprint('Request Body: $body', '📦');
          
          final response = await client.post(
            url,
            headers: ApiConfig.headers.withAuth(accessToken),
            body: body,
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body: ${response.body}', '📦');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              throw Exception('Invalid response format from server');
            }
          } else {
            String error;
            try {
              error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
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
        final responseData = json.decode(response.body);
        final data = responseData['data'];
        final note = NoteModel.fromJson(data).toDomain();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.note.addAttachment, attempts));
        }
        
        _eventController.add(OperationSuccess(ApiConfig.operations.note.addAttachment, note));
        _eventController.add(NoteUpdated(note));
        
        return note;
      } catch (e) {
        throw Exception('Failed to process server response: ${e.toString()}');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.note.addAttachment,
        e.toString(),
      ));
      rethrow;
    }
  }
} 