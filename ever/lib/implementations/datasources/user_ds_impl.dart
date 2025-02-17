import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:synchronized/synchronized.dart';
import 'package:meta/meta.dart';

import '../../domain/core/events.dart';
import '../../domain/core/retry_config.dart';
import '../../domain/core/retry_events.dart';
import '../../domain/core/service_events.dart';
import '../../domain/core/user_events.dart';
import '../../domain/datasources/user_ds.dart';
import '../../domain/entities/user.dart';
import '../config/api_config.dart';
import '../config/error_messages.dart';
import '../models/auth_credentials.dart';
import '../models/user_model.dart';
import '../../domain/core/circuit_breaker.dart';

/// Implementation of UserDataSource using HTTP and Isar
class UserDataSourceImpl implements UserDataSource {
  final Isar _isar;
  final http.Client _client;
  final StreamController<DomainEvent> _eventController;
  final Lock _refreshLock;
  final RetryConfig _retryConfig;
  final CircuitBreaker _circuitBreaker;
  String? _currentToken;

  UserDataSourceImpl({
    required Isar isar,
    required http.Client client,
    required RetryConfig retryConfig,
    required CircuitBreakerConfig circuitBreakerConfig,
  }) : _isar = isar,
       _client = client,
       _retryConfig = retryConfig,
       _eventController = StreamController<DomainEvent>.broadcast(),
       _refreshLock = Lock(),
       _circuitBreaker = CircuitBreaker(circuitBreakerConfig) {
    _initialize();
  }

  // Public interface
  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  bool get isRefreshing => _refreshLock.locked;

  @override
  Future<String?> get cachedUserSecret async {
    final credentials = await _isar.collection<AuthCredentials>().get(1);
    return credentials?.userSecret;
  }

  @override
  Future<String?> get cachedAccessToken async {
    final credentials = await _isar.collection<AuthCredentials>().get(1);
    return credentials?.accessToken;
  }

  @override
  Future<DateTime?> get tokenExpiresAt async {
    final credentials = await _isar.collection<AuthCredentials>().get(1);
    return credentials?.tokenExpiresAt;
  }

  /// Get the circuit breaker instance (for testing only)
  @visibleForTesting
  CircuitBreaker get circuitBreaker => _circuitBreaker;

  void _initialize() {
    // Forward circuit breaker events to domain events
    _circuitBreaker.events.listen((event) {
      switch (event.type) {
        case 'transition_to_open':
          _eventController.add(ServiceDegraded(event.timestamp));
          break;
        case 'transition_to_half_open':
          // No event needed for half-open state
          break;
        case 'transition_to_closed':
          _eventController.add(ServiceRestored(event.timestamp));
          break;
        case 'operation_rejected':
          _eventController.add(OperationRejected('Service unavailable'));
          break;
      }
    });
  }

  @override
  Stream<User> create(User entity) => 
    throw UnsupportedError(ErrorMessages.user.createNotSupported);

  @override
  Stream<void> delete(String id) =>
    throw UnsupportedError(ErrorMessages.user.deleteNotSupported);

  @override
  Stream<List<User>> list({Map<String, dynamic>? filters}) =>
    throw UnsupportedError(ErrorMessages.user.listNotSupported);

  @override
  Stream<User> read(String id) =>
    throw UnsupportedError(ErrorMessages.user.readNotSupported);

  @override
  Stream<User> update(User entity) =>
    throw UnsupportedError(ErrorMessages.user.updateNotSupported);

  @override
  bool isOperationSupported(String operation) {
    switch (operation) {
      case 'register':
      case 'getCurrentUser':
      case 'obtainToken':
      case 'signOut':
        return true;
      default:
        return false;
    }
  }

  @override
  Future<void> initialize() async {
    final credentials = await _isar.collection<AuthCredentials>().get(1);
    if (credentials != null) {
      _currentToken = credentials.accessToken;
      // If token is expired or about to expire, refresh it
      if (credentials.tokenExpiresAt != null && 
          credentials.tokenExpiresAt!.isBefore(DateTime.now().add(ApiConfig.tokenConfig.refreshThreshold))) {
        if (credentials.userSecret != null) {
          await obtainToken(credentials.userSecret!).first;
        }
      }
    }
  }

  /// Execute an operation with retry logic and event tracking
  Future<T> _executeWithRetry<T>(
    String operation,
    Future<T> Function() apiCall,
  ) async {
    var attempts = 0;
    var delay = _retryConfig.initialDelay;

    while (true) {
      attempts++;
      
      try {
        final result = await _circuitBreaker.execute(apiCall);
        
        // On success, emit appropriate events
        if (attempts > 1) {
          _eventController.add(RetrySuccess(operation, attempts));
        }
        
        return result;
      } catch (e) {
        // Check if we've exhausted retries
        if (attempts >= _retryConfig.maxAttempts) {
          _eventController.add(RetryExhausted(operation, e, attempts));
          rethrow;
        }

        // Emit retry attempt event and wait before next try
        _eventController.add(RetryAttempt(operation, attempts, delay, e.toString()));
        await Future.delayed(delay);
        
        // Calculate next delay with exponential backoff
        delay = Duration(milliseconds: 
          (delay.inMilliseconds * _retryConfig.backoffFactor)
            .round()
            .clamp(0, _retryConfig.maxDelay.inMilliseconds)
        );
      }
    }
  }

  @override
  Stream<User> register(String username) async* {
    try {
      _eventController.add(OperationInProgress(ApiConfig.operations.auth.register));
      
      final response = await _executeWithRetry<http.Response>(
        ApiConfig.operations.auth.register, 
        () async {
          final response = await _client.post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.endpoints.auth.register}'),
            headers: ApiConfig.headers.json,
            body: jsonEncode({
              ApiConfig.keys.auth.username: username,
            }),
          );

          if (response.statusCode == 201) {
            return response;
          }

          final error = await _handleErrorResponse(
            ApiConfig.operations.auth.register,
            response,
            ErrorMessages.auth.registrationFailed
          );
          throw error;
        }
      );

      final data = jsonDecode(response.body)[ApiConfig.keys.common.data];
      final userModel = UserModel.fromJson(data);
      final user = userModel.toDomain();
      
      await _isar.writeTxn(() async {
        await _isar.collection<AuthCredentials>().put(
          AuthCredentials()
            ..id = 1
            ..userSecret = userModel.userSecret // store as provided
        );
      });

      _eventController.add(OperationSuccess(ApiConfig.operations.auth.register, user));
      yield user;
    } catch (e) {
      final error = await _handleError(ApiConfig.operations.auth.register, e);
      throw error;
    }
  }

  @override
  Stream<String> obtainToken(String userSecret) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.obtainToken));

    try {
      final response = await _executeWithRetry<http.Response>(
        ApiConfig.operations.auth.obtainToken,
        () async {
          final response = await _client.post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.endpoints.auth.token}'),
            body: jsonEncode({ApiConfig.keys.auth.userSecret: userSecret}),
            headers: ApiConfig.headers.json,
          );

          if (response.statusCode == 200) {
            return response;
          }

          final error = await _handleErrorResponse(
            ApiConfig.operations.auth.obtainToken,
            response,
            ErrorMessages.auth.authenticationFailed
          );
          throw error;
        },
      );

      final data = jsonDecode(response.body)[ApiConfig.keys.common.data];
      final token = data[ApiConfig.keys.auth.accessToken] as String;
      _currentToken = token;
      final expiresAt = DateTime.now().add(ApiConfig.tokenConfig.tokenLifetime);
      
      await _isar.writeTxn(() async {
        final current = await _isar.collection<AuthCredentials>().get(1);
        await _isar.collection<AuthCredentials>().put(
          (current ?? AuthCredentials())
            ..id = 1
            ..userSecret = userSecret
            ..accessToken = token
            ..tokenExpiresAt = expiresAt,
        );
      });
      
      _eventController.add(TokenObtained(token, expiresAt));
      yield token;
    } catch (e) {
      final error = await _handleError(ApiConfig.operations.auth.obtainToken, e);
      throw error;
    }
  }

  @override
  Stream<User> getCurrentUser() async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.getCurrentUser));
    
    try {
      final response = await _executeWithRetry(
        ApiConfig.operations.auth.getCurrentUser,
        () async {
          if (_currentToken == null) {
            throw Exception(ErrorMessages.auth.noToken);
          }
          
          final response = await _client.get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.endpoints.auth.me}'),
            headers: ApiConfig.headers.withAuth(_currentToken!),
          );

          if (response.statusCode == 200) {
            return response;
          }
          
          final error = await _handleErrorResponse(
            ApiConfig.operations.auth.getCurrentUser,
            response,
            ErrorMessages.user.userNotFound
          );
          throw error;
        },
      );

      final data = jsonDecode(response.body)[ApiConfig.keys.common.data];
      final userModel = UserModel.fromJson(data);
      final user = userModel.toDomain();
      
      _eventController.add(OperationSuccess(ApiConfig.operations.auth.getCurrentUser, user));
      yield user;
    } catch (e) {
      final error = await _handleError(ApiConfig.operations.auth.getCurrentUser, e);
      throw error;
    }
  }

  @override
  Stream<void> signOut() async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.signOut));
    
    try {
      await _executeWithRetry(
        ApiConfig.operations.auth.signOut,
        () async {
          await _isar.writeTxn(() async {
            await _isar.collection<AuthCredentials>().clear();
          });
          _currentToken = null;
          return null;
        },
      );
      
      _eventController.add(OperationSuccess(ApiConfig.operations.auth.signOut, null));
      _eventController.add(UserLoggedOut());
      yield null;
    } catch (e) {
      final error = await _handleError(ApiConfig.operations.auth.signOut, e);
      throw error;
    }
  }

  @override
  Future<T> executeWithRefresh<T>(
    Future<T> Function() apiCall,
    Future<void> Function()? onRefreshSuccess,
  ) async {
    try {
      return await apiCall();
    } catch (e) {
      final statusCode = e is http.Response ? (e).statusCode : 
                        (e is http.ClientException ? 0 : -1);
                        
      if (statusCode == 401 || statusCode == 403) {
        // Use lock to prevent multiple simultaneous token refreshes
        return await _refreshLock.synchronized(() async {
          try {
            // Double-check if token is still invalid after acquiring lock
            try {
              return await apiCall();
            } catch (_) {
              // Original error still occurs, proceed with refresh
            }
            
            final credentials = await _isar.collection<AuthCredentials>().get(1);
            if (credentials?.userSecret == null) {
              throw Exception(ErrorMessages.auth.noUserSecret);
            }
            
            // Refresh token
            await obtainToken(credentials!.userSecret!).first;
            if (onRefreshSuccess != null) {
              await onRefreshSuccess();
            }
            
            // Retry the original call
            return await apiCall();
          } catch (refreshError) {
            // If refresh fails, ensure we emit appropriate events
            _eventController.add(OperationFailure(
              ApiConfig.operations.auth.refreshToken,
              refreshError.toString()
            ));
            rethrow;
          }
        });
      }
      rethrow;
    }
  }

  /// Handle HTTP error responses
  /// Returns a ClientException with appropriate error message
  Future<http.ClientException> _handleErrorResponse(String operation, http.Response response, String defaultMessage) async {
    String message;
    try {
      final body = jsonDecode(response.body);
      message = (body[ApiConfig.keys.common.message] as String?) ?? defaultMessage;
    } catch (e) {
      // Handle invalid JSON response
      message = response.statusCode >= 500 ? 
        ErrorMessages.operation.serverError : 
        ErrorMessages.operation.invalidResponse;
    }
    _eventController.add(OperationFailure(operation, message));
    await Future.delayed(Duration.zero); // Ensure events are processed
    return http.ClientException(message);
  }

  /// Handle general errors
  /// Returns the original error or wraps it in an appropriate exception type
  Future<Object> _handleError(String operation, Object error) async {
    if (error is CircuitBreakerException) {
      _eventController.add(OperationFailure(operation, error.message));
      await Future.delayed(Duration.zero);
      return error;
    } else if (error is http.ClientException) {
      _eventController.add(OperationFailure(operation, error.message));
      await Future.delayed(Duration.zero);
      return error;
    } else if (error is TimeoutException) {
      final message = ErrorMessages.operation.timeoutError;
      _eventController.add(OperationFailure(operation, message));
      await Future.delayed(Duration.zero);
      return TimeoutException(message);
    } else if (error is FormatException) {
      final message = ErrorMessages.operation.invalidResponse;
      _eventController.add(OperationFailure(operation, message));
      await Future.delayed(Duration.zero);
      return FormatException(message);
    } else {
      final message = error.toString();
      _eventController.add(OperationFailure(operation, message));
      await Future.delayed(Duration.zero);
      return error;
    }
  }

  @override
  void dispose() {
    _eventController.close();
    _circuitBreaker.dispose();
    _client.close();
  }
}
