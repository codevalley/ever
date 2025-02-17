import 'dart:async';

import '../../domain/core/events.dart';
import '../../domain/core/user_events.dart';
import '../../domain/datasources/user_ds.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../config/api_config.dart';

/// Implementation of UserRepository that provides reactive streams
class UserRepositoryImpl implements UserRepository {
  final UserDataSource _dataSource;
  final _eventController = StreamController<DomainEvent>.broadcast();
  
  String? _currentToken;
  String? _userSecret;
  DateTime? _tokenExpiresAt;
  User? _currentUser;

  UserRepositoryImpl(this._dataSource) {
    // Initialize state from data source
    _dataSource.cachedUserSecret.then((secret) => _userSecret = secret);
    
    // Listen to data source events and transform to domain events
    _dataSource.events.listen((event) {
      if (event is OperationSuccess) {
        if (event.data is User) {
          _handleUserSuccess(event.data as User);
        } else {
          _handleOperationFailure('Unexpected data type from data source');
        }
      } else if (event is OperationFailure) {
        _handleOperationFailure(event.error);
      } else {
        // Forward all other events
        _eventController.add(event);
      }
    });
  }

  void _handleUserSuccess(User user) {
    // Store user info
    _currentUser = user;
    
    // Check which operation completed based on the data
    if (user.userSecret != null) {
      // Registration success
      _userSecret = user.userSecret;
      _eventController.add(UserRegistered(user, user.userSecret!));
    } else {
      // User info success
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

  /// Initialize the repository state from data source
  Future<void> initialize() async {
    // Load cached user secret
    _userSecret = await _dataSource.cachedUserSecret;
    // Load cached token
    _currentToken = await _dataSource.cachedAccessToken;
    // Load token expiry
    _tokenExpiresAt = await _dataSource.tokenExpiresAt;
    // Initialize data source
    await _dataSource.initialize();
  }

  @override
  Stream<User> register(String username) async* {
    try {
      await for (final user in _dataSource.register(username)) {
        _currentUser = user;
        yield user;
      }
    } catch (e) {
      _handleOperationFailure(e.toString());
      rethrow;
    }
  }

  @override
  Stream<String> obtainToken(String userSecret) async* {
    _userSecret = userSecret;
    try {
      await for (final token in _dataSource.obtainToken(userSecret)) {
        _currentToken = token;
        _tokenExpiresAt = DateTime.now().add(ApiConfig.tokenConfig.tokenLifetime);
        yield token;
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
      await for (final user in _dataSource.getCurrentUser()) {
        _currentUser = user;
        yield user;
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
      await _dataSource.signOut().drain<void>();
      _currentToken = null;
      _tokenExpiresAt = null;
      _currentUser = null;
      _eventController.add(UserLoggedOut());
      yield null;
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
