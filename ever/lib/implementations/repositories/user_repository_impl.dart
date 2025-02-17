import 'dart:async';

import '../../domain/core/events.dart';
import '../../domain/core/user_events.dart';
import '../../domain/datasources/user_ds.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

/// Implementation of UserRepository that provides reactive streams
class UserRepositoryImpl implements UserRepository {
  final UserDataSource _dataSource;
  final _eventController = StreamController<DomainEvent>.broadcast();
  
  String? _currentToken;
  String? _userSecret;
  DateTime? _tokenExpiresAt;
  User? _currentUser;

  UserRepositoryImpl(this._dataSource) {
    // Listen to data source events and transform to domain events
    _dataSource.events.listen((event) {
      if (event is OperationInProgress) {
        _eventController.add(event);
      } else if (event is OperationSuccess) {
        if (event.data is UserModel) {
          _handleUserModelSuccess(event.data as UserModel);
        } else {
          _handleOperationFailure('Unexpected data type from data source');
        }
      } else if (event is OperationFailure) {
        _handleOperationFailure(event.error);
      }
    });
  }

  void _handleUserModelSuccess(UserModel userModel) {
    // Convert model to domain entity
    final user = userModel.toDomain();
    
    // Check which operation completed based on the data
    if (userModel.userSecret != null) {
      // Registration success
      _userSecret = userModel.userSecret;
      _eventController.add(UserRegistered(user, userModel.userSecret!));
    } else if (userModel.accessToken != null) {
      // Token acquisition success
      _currentToken = userModel.accessToken;
      _tokenExpiresAt = DateTime.now().add(ApiConfig.tokenConfig.tokenLifetime);
      _eventController.add(TokenObtained(_currentToken!, _tokenExpiresAt!));
    } else {
      // User info success
      _currentUser = user;
      _eventController.add(CurrentUserRetrieved(user));
    }
  }

  void _handleOperationFailure(String error) {
    if (_currentToken == null) {
      _eventController.add(TokenAcquisitionFailed(error));
    } else {
      _eventController.add(OperationFailure(ApiConfig.operations.auth.generic, error));
    }
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  Stream<User> register(String username) async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.register));
    
    try {
      await _dataSource.register(username);
      // Wait for UserRegistered event which contains the user
      await for (final event in events) {
        if (event is UserRegistered) {
          yield event.user;
          break;
        } else if (event is OperationFailure) {
          throw Exception(event.error);
        }
      }
    } catch (e) {
      _handleOperationFailure(e.toString());
      rethrow;
    }
  }

  @override
  Stream<String> obtainToken(String userSecret) async* {
    _userSecret = userSecret;
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.obtainToken));
    
    try {
      await _dataSource.obtainToken(userSecret);
      // Wait for TokenObtained event
      await for (final event in events) {
        if (event is TokenObtained) {
          yield event.accessToken;
          break;
        } else if (event is TokenAcquisitionFailed) {
          throw Exception(event.message);
        }
      }
    } catch (e) {
      _handleOperationFailure(e.toString());
      rethrow;
    }
  }

  @override
  Stream<String> refreshToken() async* {
    if (_userSecret == null) {
      throw Exception('No user secret available for token refresh');
    }
    
    try {
      yield* obtainToken(_userSecret!);
    } catch (e) {
      _eventController.add(TokenRefreshFailed(e.toString()));
      rethrow;
    }
  }

  @override
  Stream<User> getCurrentUser() async* {
    if (_currentToken == null) {
      throw Exception('No access token available');
    }
    
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.getCurrentUser));
    
    try {
      await _dataSource.getCurrentUser();
      // Wait for CurrentUserRetrieved event
      await for (final event in events) {
        if (event is CurrentUserRetrieved) {
          yield event.user;
          break;
        } else if (event is OperationFailure) {
          throw Exception(event.error);
        }
      }
    } catch (e) {
      _handleOperationFailure(e.toString());
      rethrow;
    }
  }

  @override
  Stream<void> signOut() async* {
    _eventController.add(OperationInProgress(ApiConfig.operations.auth.signOut));
    
    try {
      await _dataSource.signOut();
      _currentToken = null;
      _tokenExpiresAt = null;
      _currentUser = null;
      _eventController.add(UserLoggedOut());
    } catch (e) {
      _handleOperationFailure(e.toString());
      rethrow;
    }
  }

  @override
  bool get isAuthenticated => 
    _currentToken != null && 
    _tokenExpiresAt != null && 
    _tokenExpiresAt!.isAfter(DateTime.now());

  @override
  String? get currentToken => _currentToken;

  @override
  String? get currentUserSecret => _userSecret;

  @override
  DateTime? get tokenExpiresAt => _tokenExpiresAt;

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
  void dispose() {
    _eventController.close();
  }
}
