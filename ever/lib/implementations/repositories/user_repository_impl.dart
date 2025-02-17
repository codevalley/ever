import 'dart:async';

import '../../domain/core/circuit_breaker.dart';
import '../../domain/core/events.dart';
import '../../domain/core/retry_config.dart';
import '../../domain/core/user_events.dart';
import '../../domain/datasources/user_ds.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../config/api_config.dart';

/// Implementation of UserRepository that provides reactive streams
class UserRepositoryImpl implements UserRepository {
  final UserDataSource _dataSource;
  final _eventController = StreamController<DomainEvent>.broadcast();
  final CircuitBreaker _circuitBreaker;
  final RetryConfig _retryConfig;
  StreamSubscription? _dataSourceSubscription;
  
  String? _currentToken;
  String? _userSecret;
  DateTime? _tokenExpiresAt;
  User? _currentUser;

  UserRepositoryImpl(
    this._dataSource, {
    CircuitBreaker? circuitBreaker,
    RetryConfig? retryConfig,
  }) : _circuitBreaker = circuitBreaker ?? CircuitBreaker(),
       _retryConfig = retryConfig ?? RetryConfig.defaultConfig {
    // Initialize state from data source
    _dataSource.cachedUserSecret.then((secret) => _userSecret = secret);
    
    // Listen to data source events and transform to domain events
    _dataSourceSubscription = _dataSource.events.listen((event) {
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

  /// Get the currently authenticated user, if any
  User? get currentUser => _currentUser;

  /// Check if there is an authenticated user
  @override
  bool get isAuthenticated => 
    _currentUser != null && 
    _currentToken != null && 
    _tokenExpiresAt != null && 
    _tokenExpiresAt!.isAfter(DateTime.now());

  @override
  String? get currentToken => _currentToken;

  @override
  String? get currentUserSecret => _userSecret;

  @override
  DateTime? get tokenExpiresAt => _tokenExpiresAt;

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
    // If we have a token, try to get current user
    if (_currentToken != null) {
      try {
        await getCurrentUser().first;
      } catch (e) {
        // Failed to get user, clear token
        _currentToken = null;
        _tokenExpiresAt = null;
        _currentUser = null;
      }
    }
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
    try {
      await for (final token in Stream.fromFuture(_circuitBreaker.execute(() async {
        var attempts = 0;
        while (true) {
          try {
            attempts++;
            final tokenStream = _dataSource.obtainToken(userSecret.trim());
            try {
              await for (final token in tokenStream) {
                return token;
              }
              throw Exception('No token received from data source');
            } catch (streamError) {
              if (!_retryConfig.shouldRetry(streamError) || attempts >= _retryConfig.maxAttempts) {
                rethrow;
              }
              await Future.delayed(_retryConfig.getDelayForAttempt(attempts));
              continue;
            }
          } catch (error) {
            if (!_retryConfig.shouldRetry(error) || attempts >= _retryConfig.maxAttempts) {
              rethrow;
            }
            await Future.delayed(_retryConfig.getDelayForAttempt(attempts));
          }
        }
      }))) {
        _userSecret = userSecret;
        _currentToken = token;
        _tokenExpiresAt = DateTime.now().add(ApiConfig.tokenConfig.tokenLifetime);
        yield token;
      }
    } on CircuitBreakerException catch (e) {
      _eventController.add(OperationFailure(
        'obtain_token',
        'Service temporarily unavailable: ${e.message}',
      ));
      rethrow;
    } catch (e) {
      _eventController.add(OperationFailure(
        'obtain_token',
        'Failed to obtain token: ${e.toString()}',
      ));
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
    _dataSourceSubscription?.cancel();
    _circuitBreaker.dispose();
    _eventController.close();
  }
}
