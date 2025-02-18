import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/logging.dart';
import '../../domain/core/circuit_breaker.dart';
import '../../domain/core/events.dart';
import '../../domain/core/local_cache.dart';
import '../../domain/core/retry_config.dart';
import '../../domain/core/retry_events.dart';
import '../../domain/core/user_events.dart';
import '../../domain/datasources/user_ds.dart';
import '../../domain/entities/user.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

/// Implementation of UserDataSource using HTTP and local cache
class UserDataSourceImpl implements UserDataSource {
  final http.Client client;
  final LocalCache cache;
  final RetryConfig retryConfig;
  final CircuitBreakerConfig circuitBreakerConfig;
  
  final _eventController = StreamController<DomainEvent>.broadcast();
  final _tokenRefreshLock = Object();
  bool _isRefreshing = false;

  UserDataSourceImpl({
    required this.client,
    required this.cache,
    required this.retryConfig,
    required this.circuitBreakerConfig,
  });

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  bool get isRefreshing => _isRefreshing;

  @override
  Future<void> initialize() async {
    await cache.initialize();
  }

  @override
  Future<String?> get cachedUserSecret async {
    return await cache.get<String>('userSecret');
  }

  @override
  Future<String?> get cachedAccessToken async {
    return await cache.get<String>('accessToken');
  }

  @override
  Future<DateTime?> get tokenExpiresAt async {
    final expiresAt = await cache.get<String>('tokenExpiresAt');
    return expiresAt != null ? DateTime.parse(expiresAt) : null;
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
  Stream<User> register(String username) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.register));
    var attempts = 0;

    try {
      final response = await _executeWithRetry(
        ApiConfig.operations.auth.register,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.auth.register}');
          final body = json.encode({ApiConfig.keys.auth.username: username});
          
          iprint('API Request: POST $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.json}', '📤');
          iprint('Request Body: $body', '📦');
          
          final response = await client.post(
            url,
            headers: ApiConfig.headers.json,
            body: body,
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body Length: ${response.body.length} bytes', '📦');
          iprint('Response Body Raw: ${response.body.split('').map((c) => c.codeUnitAt(0).toRadixString(16).padLeft(2, '0')).join(' ')}', '📦');
          iprint('Response Body Text: ${response.body}', '📦');

          if (response.statusCode == 201) {
            try {
              // Validate JSON response
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                eprint('Invalid response format: missing data field');
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              eprint('Invalid JSON response: ${e.toString()}');
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
              eprint('Server error: $error');
              throw http.ClientException('Service unavailable');
            }
            eprint('Client error: $error');
            throw Exception(error);
          }
        },
      );

      try {
        final responseData = json.decode(response.body);
        final data = responseData['data'];
        
        dprint('Parsed response data: $data');
        dprint('Available fields: ${data.keys.join(', ')}');
        
        // Validate required fields
        if (!data.containsKey(ApiConfig.keys.auth.userSecret)) {
          throw Exception('Invalid response format: missing user_secret field');
        }
        if (!data.containsKey(ApiConfig.keys.user.id)) {
          throw Exception('Invalid response format: missing id field');
        }
        if (!data.containsKey(ApiConfig.keys.auth.username)) {
          throw Exception('Invalid response format: missing username field');
        }

        final userSecret = data[ApiConfig.keys.auth.userSecret] as String;
        
        // Save user secret
        await cache.set('userSecret', userSecret);

        final user = UserModel.fromJson(data).toDomain();
        dprint('Created user model and converted to domain entity');
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.auth.register, attempts));
        }
        
        dprint('Adding OperationSuccess event');
        _eventController.add(OperationSuccess(ApiConfig.operations.auth.register, user));
        
        dprint('Adding UserRegistered event');
        _eventController.add(UserRegistered(user, userSecret));
        
        dprint('Yielding user and completing');
        yield user;
        dprint('Registration complete');
      } catch (e) {
        eprint('Failed to process response: ${e.toString()}');
        throw Exception('Failed to process server response: ${e.toString()}');
      }
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.auth.register,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Stream<String> obtainToken(String userSecret) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.obtainToken));
    var attempts = 0;

    try {
      final response = await _executeWithRetry(
        ApiConfig.operations.auth.obtainToken,
        () async {
          attempts++;
          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.auth.token}');
          final body = json.encode({ApiConfig.keys.auth.userSecret: userSecret});
          
          iprint('API Request: POST $url', '🌐');
          iprint('Request Headers: ${ApiConfig.headers.json}', '📤');
          iprint('Request Body: $body', '📦');
          
          final response = await client.post(
            url,
            headers: ApiConfig.headers.json,
            body: body,
          );

          iprint('API Response Status: ${response.statusCode}', '📥');
          iprint('Response Body Length: ${response.body.length} bytes', '📦');
          iprint('Response Body Text: ${response.body}', '📦');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                eprint('Invalid response format: missing data field');
                throw Exception('Invalid response format from server');
              }
              final data = responseData['data'];
              if (!data.containsKey(ApiConfig.keys.auth.accessToken)) {
                eprint('Invalid response format: missing access_token field');
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              eprint('Invalid JSON response: ${e.toString()}');
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
              eprint('Server error: $error');
              throw http.ClientException('Service unavailable');
            }
            eprint('Client error: $error');
            throw Exception(error);
          }
        },
      );

      final data = json.decode(response.body)[ApiConfig.keys.common.data];
      final token = data[ApiConfig.keys.auth.accessToken] as String;
      final expiresAt = DateTime.now().add(ApiConfig.tokenConfig.tokenLifetime);
      
      // Save credentials
      await Future.wait([
        cache.set('userSecret', userSecret),
        cache.set('accessToken', token),
        cache.set('tokenExpiresAt', expiresAt.toIso8601String()),
      ]);

      if (attempts > 1) {
        _eventController.add(RetrySuccess(ApiConfig.operations.auth.obtainToken, attempts));
      }
      _eventController.add(OperationSuccess(ApiConfig.operations.auth.obtainToken, token));
      _eventController.add(TokenObtained(token, expiresAt));
      yield token;
    } catch (e) {
      _eventController.add(TokenAcquisitionFailed(e.toString()));
      rethrow;
    }
  }

  @override
  Stream<User> getCurrentUser() async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.getCurrentUser));
    dprint('Starting getCurrentUser flow');

    try {
      final token = await cachedAccessToken;
      if (token == null) {
        eprint('No access token available');
        throw Exception('No access token available');
      }

      final userSecret = await cachedUserSecret;
      if (userSecret == null) {
        eprint('No user secret available for token refresh');
        throw Exception('No user secret available for token refresh');
      }

      try {
        dprint('Using token: ${token.length > 10 ? "${token.substring(0, 10)}..." : token}');
        final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.auth.me}');
        iprint('API Request: GET $url', '🌐');
        iprint('Request Headers Authorization: Bearer ${token.length > 10 ? "${token.substring(0, 10)}..." : token}', '📤');
        
        final response = await client.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        iprint('API Response Status: ${response.statusCode}', '📥');
        iprint('Response Body Length: ${response.body.length} bytes', '📦');
        iprint('Response Body Text: ${response.body}', '📦');

        if (response.statusCode == 200) {
          try {
            final responseData = json.decode(response.body);
            dprint('Parsed response data: $responseData');
            if (!responseData.containsKey('data')) {
              eprint('Invalid response format: missing data field');
              throw Exception('Invalid response format from server');
            }
            final data = responseData['data'];
            final user = UserModel.fromJson(data).toDomain();
            dprint('Successfully converted to user model');
            _eventController.add(CurrentUserRetrieved(user));
            dprint('Emitted CurrentUserRetrieved event');
            yield user;
            dprint('Yielded user object');
          } catch (e) {
            eprint('Invalid JSON response: ${e.toString()}');
            throw Exception('Invalid response format from server');
          }
        } else {
          String error;
          try {
            error = json.decode(response.body)[ApiConfig.keys.common.message] ?? 'Unknown error';
          } catch (e) {
            error = 'Failed to parse error message: ${response.body}';
          }
          
          if (response.statusCode == 401) {
            dprint('Token expired, attempting refresh');
            // Try to refresh token
            await for (final newToken in obtainToken(userSecret)) {
              dprint('Token refreshed successfully');
              // Retry with new token
              final retryResponse = await client.get(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $newToken',
                },
              );

              if (retryResponse.statusCode == 200) {
                final retryData = json.decode(retryResponse.body)['data'];
                final user = UserModel.fromJson(retryData).toDomain();
                _eventController.add(CurrentUserRetrieved(user));
                yield user;
                return;
              }
            }
            throw Exception('Token refresh failed');
          } else if (response.statusCode >= 500) {
            eprint('Server error: $error');
            throw http.ClientException('Service unavailable');
          }
          eprint('Client error: $error');
          throw Exception(error);
        }
      } catch (e) {
        eprint('Failed to get current user: ${e.toString()}');
        _eventController.add(OperationFailure(
          ApiConfig.operations.auth.getCurrentUser,
          e.toString(),
        ));
        rethrow;
      }
    } catch (e) {
      eprint('Failed to get current user: ${e.toString()}');
      _eventController.add(OperationFailure(
        ApiConfig.operations.auth.getCurrentUser,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Stream<void> signOut() async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.signOut));

    try {
      // Clear credentials
      await cache.clear();
      _eventController.add(UserLoggedOut());
      yield null;
    } catch (e) {
      _eventController.add(OperationFailure(
        ApiConfig.operations.auth.signOut,
        e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Future<T> executeWithRefresh<T>(
    Future<T> Function() apiCall,
    Future<void> Function()? onRefreshSuccess,
  ) async {
    try {
      dprint('Starting executeWithRefresh');
      dprint('Executing initial API call');
      return await apiCall();
    } catch (e) {
      wprint('API call failed: ${e.toString()}');
      if (e.toString().contains('Token expired') || e.toString().contains('401') || e.toString().contains('403')) {
        dprint('Token expired, attempting refresh');
        // Try to refresh token
        final userSecret = await cachedUserSecret;
        if (userSecret == null) {
          eprint('No user secret available for token refresh');
          throw Exception('No user secret available for token refresh');
        }

        dprint('Checking refresh lock status');
        // Use lock to prevent multiple concurrent refreshes
        await synchronized(_tokenRefreshLock, () async {
          dprint('Inside synchronized block');
          if (_isRefreshing) {
            dprint('Token refresh already in progress, waiting...');
            // Wait for other refresh to complete
            while (_isRefreshing) {
              await Future.delayed(Duration(milliseconds: 100));
              dprint('Still waiting for token refresh...');
            }
          } else {
            dprint('Starting token refresh');
            _isRefreshing = true;
            try {
              dprint('Calling obtainToken');
              await obtainToken(userSecret).first;
              dprint('Token refresh successful');
              if (onRefreshSuccess != null) {
                dprint('Executing onRefreshSuccess callback');
                await onRefreshSuccess();
              }
            } catch (e) {
              eprint('Token refresh failed: ${e.toString()}');
              rethrow;
            } finally {
              dprint('Resetting refresh flag');
              _isRefreshing = false;
            }
          }
        });

        dprint('Retrying original API call after token refresh');
        return await apiCall();
      }
      eprint('Non-token-related error: ${e.toString()}');
      rethrow;
    }
  }

  @override
  Stream<User> create(User entity) {
    throw UnimplementedError('Create operation not supported for User entity');
  }

  @override
  Stream<void> delete(String id) {
    throw UnimplementedError('Delete operation not supported for User entity');
  }

  @override
  Stream<List<User>> list({Map<String, dynamic>? filters}) {
    throw UnimplementedError('List operation not supported for User entity');
  }

  @override
  Stream<User> read(String id) {
    throw UnimplementedError('Read operation not supported for User entity');
  }

  @override
  Stream<User> update(User entity) {
    throw UnimplementedError('Update operation not supported for User entity');
  }

  @override
  bool isOperationSupported(String operation) => false;

  @override
  void dispose() {
    _eventController.close();
  }
}

/// Helper function to synchronize token refresh
Future<T> synchronized<T>(
  Object lock,
  Future<T> Function() callback,
) async {
  if (!_locks.containsKey(lock)) {
    _locks[lock] = _Lock();
  }
  
  final lockObj = _locks[lock] as _Lock;
  
  try {
    dprint('Waiting for lock');
    await lockObj.acquire();
    dprint('Lock acquired');
    
    final result = await callback();
    dprint('Operation completed successfully');
    return result;
  } finally {
    dprint('Releasing lock');
    lockObj.release();
    if (!lockObj.isLocked) {
      _locks.remove(lock);
    }
  }
}

/// Internal lock implementation
class _Lock {
  bool _locked = false;
  final _waitQueue = <Completer<void>>[];

  bool get isLocked => _locked;

  Future<void> acquire() async {
    if (!_locked) {
      _locked = true;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
  }

  void release() {
    if (!_locked) return;

    if (_waitQueue.isEmpty) {
      _locked = false;
    } else {
      final next = _waitQueue.removeAt(0);
      next.complete();
    }
  }
}

final _locks = <Object, _Lock>{};
