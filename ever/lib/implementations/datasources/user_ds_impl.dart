import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:synchronized/synchronized.dart';

import '../../domain/core/events.dart';
import '../../domain/datasources/user_ds.dart';
import '../../domain/entities/user.dart';
import '../config/api_config.dart';
import '../models/auth_credentials.dart';
import '../models/user_model.dart';

/// Implementation of UserDataSource using HTTP and Isar
class UserDataSourceImpl implements UserDataSource {
  final Isar _isar;
  final _eventController = StreamController<DomainEvent>.broadcast();
  final _refreshLock = Lock(); // For synchronizing token refresh
  
  bool _isRefreshing = false;
  String? _currentToken;

  UserDataSourceImpl({
    required Isar isar,
  }) : _isar = isar;

  @override
  Future<void> initialize() async {
    final credentials = await _isar.authCredentials.get(1);
    if (credentials != null) {
      _currentToken = credentials.accessToken;
      // If token is expired or about to expire, refresh it
      if (credentials.isExpiredOrExpiring(ApiConfig.tokenConfig.refreshThreshold)) {
        if (credentials.userSecret != null) {
          await obtainToken(credentials.userSecret!);
        }
      }
    }
  }

  @override
  Future<void> register(String username) async {
    _eventController.add(OperationInProgress());
    
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.apiBaseUrl + ApiConfig.endpoints.auth.register),
        body: jsonEncode({ApiConfig.keys.auth.username: username}),
        headers: ApiConfig.headers.json,
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body)[ApiConfig.keys.common.data];
        final userSecret = data[ApiConfig.keys.auth.userSecret] as String;
        
        // Cache user secret
        await _isar.writeTxn(() async {
          await _isar.authCredentials.put(
            AuthCredentials().copyWithSecret(userSecret: userSecret),
          );
        });
        
        // Convert to UserModel and emit
        final userModel = UserModel.fromJson(data);
        _eventController.add(OperationSuccess(userModel));
      } else {
        _handleErrorResponse(response, 'Registration failed');
      }
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<void> obtainToken(String userSecret) async {
    return _refreshLock.synchronized(() async {
      if (_isRefreshing) return;
      _isRefreshing = true;
      _eventController.add(OperationInProgress());

      try {
        final response = await http.post(
          Uri.parse(ApiConfig.apiBaseUrl + ApiConfig.endpoints.auth.token),
          body: jsonEncode({ApiConfig.keys.auth.userSecret: userSecret}),
          headers: ApiConfig.headers.json,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body)[ApiConfig.keys.common.data];
          _currentToken = data[ApiConfig.keys.auth.accessToken] as String;
          final expiresAt = DateTime.now().add(ApiConfig.tokenConfig.tokenLifetime);
          
          // Cache token and expiration
          await _isar.writeTxn(() async {
            final current = await _isar.authCredentials.get(1);
            await _isar.authCredentials.put(
              (current ?? AuthCredentials()).copyWithToken(
                accessToken: _currentToken!,
                expiresAt: expiresAt,
              ),
            );
          });
          
          // Convert to UserModel and emit
          final userModel = UserModel.fromJson(data);
          _eventController.add(OperationSuccess(userModel));
        } else {
          _handleErrorResponse(response, 'Token acquisition failed');
        }
      } catch (e) {
        _handleError(e);
      } finally {
        _isRefreshing = false;
      }
    });
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
          final credentials = await _isar.authCredentials.get(1);
          if (credentials?.userSecret != null) {
            await obtainToken(credentials!.userSecret!);
            if (onRefreshSuccess != null) {
              await onRefreshSuccess();
            }
            // Retry the original call
            return await apiCall();
          }
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> getCurrentUser() async {
    _eventController.add(OperationInProgress());
    
    try {
      final response = await executeWithRefresh(
        () => http.get(
          Uri.parse(ApiConfig.apiBaseUrl + ApiConfig.endpoints.auth.me),
          headers: ApiConfig.headers.withAuth(_currentToken!),
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)[ApiConfig.keys.common.data];
        final userModel = UserModel.fromJson(data);
        _eventController.add(OperationSuccess(userModel));
      } else {
        _handleErrorResponse(response, 'Failed to get user info');
      }
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _isar.writeTxn(() async {
      await _isar.authCredentials.clear();
    });
    _currentToken = null;
    _eventController.add(OperationSuccess(null));
  }

  /// Handle HTTP error responses
  void _handleErrorResponse(http.Response response, String defaultMessage) {
    final body = jsonDecode(response.body);
    _eventController.add(
      OperationFailure(body[ApiConfig.keys.common.message] ?? defaultMessage),
    );
  }

  /// Handle general errors
  void _handleError(Object error) {
    _eventController.add(OperationFailure(error.toString()));
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  bool get isRefreshing => _isRefreshing;

  @override
  Future<String?> get cachedUserSecret async {
    final credentials = await _isar.authCredentials.get(1);
    return credentials?.userSecret;
  }

  @override
  Future<String?> get cachedAccessToken async {
    final credentials = await _isar.authCredentials.get(1);
    return credentials?.accessToken;
  }

  @override
  Future<DateTime?> get tokenExpiresAt async {
    final credentials = await _isar.authCredentials.get(1);
    return credentials?.tokenExpiresAt;
  }

  void dispose() {
    _eventController.close();
  }
}
