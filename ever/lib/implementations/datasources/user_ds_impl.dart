import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
        print('🔄 [Attempt $attempts] Executing $operation');
        return await apiCall();
      } catch (e) {
        final elapsed = DateTime.now().difference(startTime);
        print('⚠️ [Error] $operation failed after ${elapsed.inMilliseconds}ms: $e');
        
        if (!retryConfig.shouldRetry(e) || attempts >= retryConfig.maxAttempts) {
          if (attempts > 1) {
            print('❌ [Retry Exhausted] $operation failed after $attempts attempts');
            _eventController.add(RetryExhausted(operation, e, attempts));
          }
          rethrow;
        }
        
        final delay = retryConfig.getDelayForAttempt(attempts);
        print('⏳ [Retry] Waiting ${delay.inMilliseconds}ms before attempt ${attempts + 1}');
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
          
          print('🌐 [API Request] POST $url');
          print('📤 [Request Headers] ${ApiConfig.headers.json}');
          print('📦 [Request Body] $body');
          
          final response = await client.post(
            url,
            headers: ApiConfig.headers.json,
            body: body,
          );

          print('📥 [API Response] Status: ${response.statusCode}');
          print('📦 [Response Body Length] ${response.body.length} bytes');
          print('📦 [Response Body] Raw: ${response.body.split('').map((c) => c.codeUnitAt(0).toRadixString(16).padLeft(2, '0')).join(' ')}');
          print('📦 [Response Body] Text: ${response.body}');

          if (response.statusCode == 201) {
            try {
              // Validate JSON response
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                print('❌ [API Error] Invalid response format: missing data field');
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              print('❌ [API Error] Invalid JSON response: ${e.toString()}');
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
              print('❌ [API Error] Server error: $error');
              throw http.ClientException('Service unavailable');
            }
            print('❌ [API Error] Client error: $error');
            throw Exception(error);
          }
        },
      );

      try {
        final responseData = json.decode(response.body);
        final data = responseData['data'];
        
        print('🔍 [Debug] Parsed response data: $data');
        print('🔍 [Debug] Available fields: ${data.keys.join(', ')}');
        
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
        print('🔍 [Debug] Created user model and converted to domain entity');
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(ApiConfig.operations.auth.register, attempts));
        }
        
        print('🔍 [Debug] Adding OperationSuccess event');
        _eventController.add(OperationSuccess(ApiConfig.operations.auth.register, user));
        
        print('🔍 [Debug] Adding UserRegistered event');
        _eventController.add(UserRegistered(user, userSecret));
        
        print('🔍 [Debug] Yielding user and completing');
        yield user;
        print('🔍 [Debug] Registration complete');
      } catch (e) {
        print('❌ [API Error] Failed to process response: ${e.toString()}');
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
          
          print('🌐 [API Request] POST $url');
          print('📤 [Request Headers] ${ApiConfig.headers.json}');
          print('📦 [Request Body] $body');
          
          final response = await client.post(
            url,
            headers: ApiConfig.headers.json,
            body: body,
          );

          print('📥 [API Response] Status: ${response.statusCode}');
          print('📦 [Response Body Length] ${response.body.length} bytes');
          print('📦 [Response Body] Text: ${response.body}');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              if (!responseData.containsKey('data')) {
                print('❌ [API Error] Invalid response format: missing data field');
                throw Exception('Invalid response format from server');
              }
              final data = responseData['data'];
              if (!data.containsKey(ApiConfig.keys.auth.accessToken)) {
                print('❌ [API Error] Invalid response format: missing access_token field');
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              print('❌ [API Error] Invalid JSON response: ${e.toString()}');
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
              print('❌ [API Error] Server error: $error');
              throw http.ClientException('Service unavailable');
            }
            print('❌ [API Error] Client error: $error');
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
    print('🔍 [Debug] Starting getCurrentUser flow');
    print('🔍 [Debug] Current token available: ${await cachedAccessToken != null}');

    try {
      final response = await executeWithRefresh(
        () async {
          final token = await cachedAccessToken;
          if (token == null) {
            print('❌ [Error] No access token available');
            throw Exception('No access token available');
          }

          final url = Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.auth.me}');
          print('🌐 [API Request] GET $url');
          print('📤 [Request Headers] Authorization: Bearer ${token.substring(0, 10)}...');
          
          print('🔍 [Debug] Sending request to /auth/me endpoint');
          final response = await client.get(
            url,
            headers: ApiConfig.headers.withAuth(token),
          );
          print('🔍 [Debug] Received response from /auth/me endpoint');

          print('📥 [API Response] Status: ${response.statusCode}');
          print('📦 [Response Body Length] ${response.body.length} bytes');
          print('📦 [Response Body] Raw: ${response.body.split('').map((c) => c.codeUnitAt(0).toRadixString(16).padLeft(2, '0')).join(' ')}');
          print('📦 [Response Body] Text: ${response.body}');

          if (response.statusCode == 200) {
            try {
              final responseData = json.decode(response.body);
              print('🔍 [Debug] Parsed response data: $responseData');
              if (!responseData.containsKey('data')) {
                print('❌ [API Error] Invalid response format: missing data field');
                throw Exception('Invalid response format from server');
              }
              return response;
            } catch (e) {
              print('❌ [API Error] Invalid JSON response: ${e.toString()}');
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
              print('❌ [API Error] Token expired or invalid');
              throw Exception('Token expired');
            } else if (response.statusCode >= 500) {
              print('❌ [API Error] Server error: $error');
              throw http.ClientException('Service unavailable');
            }
            print('❌ [API Error] Client error: $error');
            throw Exception(error);
          }
        },
        () async {
          print('🔄 [Debug] Token refreshed, retrying user info request');
        },
      );

      final data = json.decode(response.body)[ApiConfig.keys.common.data];
      print('🔍 [Debug] Successfully parsed user data: $data');
      final user = UserModel.fromJson(data).toDomain();
      print('🔍 [Debug] Successfully converted to user model');
      _eventController.add(CurrentUserRetrieved(user));
      print('🔍 [Debug] Emitted CurrentUserRetrieved event');
      yield user;
      print('🔍 [Debug] Yielded user object');
    } catch (e) {
      print('❌ [Error] Failed to get current user: ${e.toString()}');
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
      print('🔍 [Debug] Starting executeWithRefresh');
      print('🔍 [Debug] Executing initial API call');
      return await apiCall();
    } catch (e) {
      print('⚠️ [Debug] API call failed: ${e.toString()}');
      if (e.toString().contains('Token expired') || e.toString().contains('401') || e.toString().contains('403')) {
        print('🔄 [Debug] Token expired, attempting refresh');
        // Try to refresh token
        final userSecret = await cachedUserSecret;
        if (userSecret == null) {
          print('❌ [Error] No user secret available for token refresh');
          throw Exception('No user secret available for token refresh');
        }

        print('🔍 [Debug] Checking refresh lock status');
        // Use lock to prevent multiple concurrent refreshes
        await synchronized(_tokenRefreshLock, () async {
          print('🔍 [Debug] Inside synchronized block');
          if (_isRefreshing) {
            print('🔍 [Debug] Token refresh already in progress, waiting...');
            // Wait for other refresh to complete
            while (_isRefreshing) {
              await Future.delayed(Duration(milliseconds: 100));
              print('🔄 [Debug] Still waiting for token refresh...');
            }
          } else {
            print('🔍 [Debug] Starting token refresh');
            _isRefreshing = true;
            try {
              print('🔍 [Debug] Calling obtainToken');
              await obtainToken(userSecret).first;
              print('✅ [Debug] Token refresh successful');
              if (onRefreshSuccess != null) {
                print('🔍 [Debug] Executing onRefreshSuccess callback');
                await onRefreshSuccess();
              }
            } catch (e) {
              print('❌ [Error] Token refresh failed: ${e.toString()}');
              rethrow;
            } finally {
              print('🔍 [Debug] Resetting refresh flag');
              _isRefreshing = false;
            }
          }
        });

        print('🔍 [Debug] Retrying original API call after token refresh');
        return await apiCall();
      }
      print('❌ [Error] Non-token-related error: ${e.toString()}');
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
    print('🔍 [Debug] Waiting for lock');
    await lockObj.acquire();
    print('🔍 [Debug] Lock acquired');
    
    final result = await callback();
    print('🔍 [Debug] Operation completed successfully');
    return result;
  } finally {
    print('🔍 [Debug] Releasing lock');
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
