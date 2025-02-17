import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:synchronized/synchronized.dart';

import '../../domain/core/events.dart';
import '../../domain/core/retry_config.dart';
import '../../domain/core/retry_events.dart';
import '../../domain/datasources/user_ds.dart';
import '../../domain/entities/user.dart';
import '../config/api_config.dart';
import '../config/error_messages.dart';
import '../models/auth_credentials.dart';
import '../models/user_model.dart';

/// Implementation of UserDataSource using HTTP and Isar
class UserDataSourceImpl implements UserDataSource {
  final Isar _isar;
  final http.Client _client;
  final _eventController = StreamController<DomainEvent>.broadcast();
  final _refreshLock = Lock();
  
  final RetryConfig _retryConfig;
  bool _isRefreshing = false;
  String? _currentToken;

  UserDataSourceImpl({
    required Isar isar,
    http.Client? client,
    RetryConfig? retryConfig,
  }) : _isar = isar,
       _client = client ?? http.Client(),
       _retryConfig = retryConfig ?? RetryConfig.defaultConfig;

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
  bool isOperationSupported(String operation) => false;

  @override
  Future<void> initialize() async {
    final collection = _isar.collection<AuthCredentials>();
    final credentials = await collection.get(1);
    if (credentials != null) {
      _currentToken = credentials.accessToken;
      // If token is expired or about to expire, refresh it
      if (credentials.isExpiredOrExpiring(ApiConfig.tokenConfig.refreshThreshold)) {
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
    int attempts = 0;
    
    while (true) {
      try {
        attempts++;
        final result = await apiCall();
        
        if (attempts > 1) {
          _eventController.add(RetrySuccess(operation, attempts));
        }
        
        return result;
      } catch (error) {
        if (!_retryConfig.shouldRetry(error) || attempts >= _retryConfig.maxAttempts) {
          if (attempts > 1) {
            _eventController.add(RetryExhausted(operation, error, attempts));
          }
          rethrow;
        }
        
        final delay = _retryConfig.getDelayForAttempt(attempts);
        _eventController.add(RetryAttempt(operation, attempts, delay, error));
        await Future.delayed(delay);
      }
    }
  }

  @override
  Stream<User> register(String username) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.register));
    
    try {
      final response = await _executeWithRetry(
        ApiConfig.operations.auth.register,
        () => _client.post(
          Uri.parse(ApiConfig.apiBaseUrl + ApiConfig.endpoints.auth.register),
          body: jsonEncode({ApiConfig.keys.auth.username: username}),
          headers: ApiConfig.headers.json,
        ),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body)[ApiConfig.keys.common.data];
        final userSecret = data[ApiConfig.keys.auth.userSecret] as String;
        
        await _isar.writeTxn<void>(() async {
          await _isar.collection<AuthCredentials>().put(
            AuthCredentials().copyWithSecret(userSecret: userSecret),
          );
        });
        
        final userModel = UserModel.fromJson(data);
        _eventController.add(OperationSuccess(ApiConfig.operations.auth.register, userModel));
        yield userModel.toDomain();
      } else {
        final error = await _handleErrorResponse(
          ApiConfig.operations.auth.register,
          response,
          ErrorMessages.auth.registrationFailed
        );
        throw error;
      }
    } catch (e) {
      final error = await _handleError(ApiConfig.operations.auth.register, e);
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
      if (e is http.ClientException || e is http.Response) {
        final statusCode = e is http.Response ? e.statusCode : 0;
        if (statusCode == 401 || statusCode == 403) {
          // Token expired, try to refresh
          final credentials = await _isar.collection<AuthCredentials>().get(1);
          if (credentials?.userSecret != null) {
            await obtainToken(credentials!.userSecret!).first;
            if (onRefreshSuccess != null) {
              await onRefreshSuccess();
            }
            // Retry the original call
            return await apiCall();
          }
          throw Exception(ErrorMessages.auth.noUserSecret);
        }
      }
      rethrow;
    }
  }

  @override
  Stream<String> obtainToken(String userSecret) async* {
    if (_isRefreshing) {
      throw Exception(ErrorMessages.operation.operationInProgress);
    }
    
    _isRefreshing = true;
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.obtainToken));

    try {
      String? token = await _refreshLock.synchronized(() async {
        try {
          final response = await _executeWithRetry(
            ApiConfig.operations.auth.obtainToken,
            () => _client.post(
              Uri.parse(ApiConfig.apiBaseUrl + ApiConfig.endpoints.auth.token),
              body: jsonEncode({ApiConfig.keys.auth.userSecret: userSecret}),
              headers: ApiConfig.headers.json,
            ),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body)[ApiConfig.keys.common.data];
            _currentToken = data[ApiConfig.keys.auth.accessToken] as String;
            final expiresAt = DateTime.now().add(ApiConfig.tokenConfig.tokenLifetime);
            
            await _isar.writeTxn<void>(() async {
              final current = await _isar.collection<AuthCredentials>().get(1);
              await _isar.collection<AuthCredentials>().put(
                (current ?? AuthCredentials()).copyWithToken(
                  accessToken: _currentToken!,
                  expiresAt: expiresAt,
                ),
              );
            });
            
            _eventController.add(OperationSuccess(ApiConfig.operations.auth.obtainToken, _currentToken));
            return _currentToken;
          } else {
            final error = await _handleErrorResponse(
              ApiConfig.operations.auth.obtainToken,
              response,
              ErrorMessages.auth.authenticationFailed
            );
            throw error;
          }
        } catch (e) {
          final error = await _handleError(ApiConfig.operations.auth.obtainToken, e);
          throw error;
        }
      });

      if (token != null) {
        yield token;
      }
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Stream<User> getCurrentUser() async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.getCurrentUser));
    
    try {
      final response = await _executeWithRetry(
        ApiConfig.operations.auth.getCurrentUser,
        () => _client.get(
          Uri.parse(ApiConfig.apiBaseUrl + ApiConfig.endpoints.auth.me),
          headers: ApiConfig.headers.withAuth(_currentToken!),
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)[ApiConfig.keys.common.data];
        final userModel = UserModel.fromJson(data);
        _eventController.add(OperationSuccess(ApiConfig.operations.auth.getCurrentUser, userModel));
        yield userModel.toDomain();
      } else {
        final error = await _handleErrorResponse(
          ApiConfig.operations.auth.getCurrentUser,
          response,
          ErrorMessages.user.userNotFound
        );
        throw error;
      }
    } catch (e) {
      final error = await _handleError(ApiConfig.operations.auth.getCurrentUser, e);
      throw error;
    }
  }

  @override
  Stream<void> signOut() async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.signOut));
    try {
      await _isar.writeTxn<void>(() async {
        await _isar.collection<AuthCredentials>().clear();
      });
      _currentToken = null;
      _eventController.add(OperationSuccess(ApiConfig.operations.auth.signOut, null));
    } catch (e) {
      final error = await _handleError(ApiConfig.operations.auth.signOut, e);
      throw error;
    }
  }

  /// Handle HTTP error responses
  /// Returns the error message that should be thrown
  Future<String> _handleErrorResponse(String operation, http.Response response, String defaultMessage) async {
    final body = jsonDecode(response.body);
    final message = body[ApiConfig.keys.common.message] ?? defaultMessage;
    _eventController.add(OperationFailure(operation, message));
    await Future.delayed(Duration.zero); // Ensure events are processed
    return message;
  }

  /// Handle general errors
  /// Returns the error message that should be thrown
  Future<String> _handleError(String operation, Object error) async {
    String message = error.toString();
    if (error is http.ClientException) {
      message = ErrorMessages.operation.networkError;
    } else if (error is TimeoutException) {
      message = ErrorMessages.operation.timeoutError;
    }
    _eventController.add(OperationFailure(operation, message));
    await Future.delayed(Duration.zero); // Ensure events are processed
    return message;
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  bool get isRefreshing => _isRefreshing;

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

  @override
  void dispose() {
    _eventController.close();
  }
}
