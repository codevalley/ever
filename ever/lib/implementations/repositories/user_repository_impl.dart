import 'dart:async';

import '../../domain/core/events.dart';
import '../../domain/core/user_events.dart';
import '../../domain/datasources/user_ds.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

/// Implementation of UserRepository
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
      _eventController.add(OperationFailure(error));
    }
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void register(String username) {
    _dataSource.register(username);
  }

  @override
  void obtainToken(String userSecret) {
    _userSecret = userSecret;
    _dataSource.obtainToken(userSecret);
  }

  @override
  void refreshToken() {
    if (_userSecret == null) {
      _eventController.add(
        TokenRefreshFailed('No user secret available for token refresh'),
      );
      return;
    }
    _dataSource.obtainToken(_userSecret!);
  }

  @override
  void getCurrentUser() {
    if (_currentToken == null) {
      _eventController.add(
        OperationFailure('No access token available'),
      );
      return;
    }
    _dataSource.getCurrentUser();
  }

  @override
  void signOut() {
    _currentToken = null;
    _tokenExpiresAt = null;
    _currentUser = null;
    _eventController.add(UserLoggedOut());
  }

  @override
  bool get isAuthenticated => _currentToken != null && 
    _tokenExpiresAt != null && 
    _tokenExpiresAt!.isAfter(DateTime.now());

  @override
  String? get currentToken => _currentToken;

  @override
  String? get currentUserSecret => _userSecret;

  @override
  DateTime? get tokenExpiresAt => _tokenExpiresAt;

  void dispose() {
    _eventController.close();
  }
}
