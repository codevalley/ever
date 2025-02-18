import 'dart:async';

import '../../../domain/core/events.dart';
import '../../../domain/core/user_events.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../../domain/usecases/base_usecase.dart';

/// Parameters for login operation
class LoginParams {
  /// User secret obtained during registration
  /// Used to obtain new access tokens
  final String userSecret;

  const LoginParams({
    required this.userSecret,
  });

  /// Validate login parameters
  bool validate() {
    if (userSecret.trim().isEmpty) {
      return false;
    }
    if (userSecret.length < 8) {
      return false;
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(userSecret) || !RegExp(r'[0-9]').hasMatch(userSecret)) {
      return false;
    }
    return true;
  }

  String? validateWithMessage() {
    if (userSecret.trim().isEmpty) {
      return 'User secret cannot be empty';
    }
    if (userSecret.length < 8) {
      return 'User secret must be at least 8 characters';
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(userSecret) || !RegExp(r'[0-9]').hasMatch(userSecret)) {
      return 'User secret must contain at least one letter and one number';
    }
    return null;
  }
}

/// Use case for user login
/// 
/// Flow:
/// 1. Validates the user secret
/// 2. Calls repository to obtain token with retries
/// 3. Emits appropriate events:
///    - [OperationInProgress]: When token acquisition starts
///    - [TokenObtained]: When token is obtained successfully
///    - [OperationFailure]: When validation or token acquisition fails
///    - [TokenExpiring]: When token is about to expire
///    - [TokenExpired]: When token has expired
class LoginUseCase extends BaseUseCase<LoginParams> {
  final UserRepository _repository;
  final _events = StreamController<DomainEvent>.broadcast();
  StreamSubscription<String>? _tokenSubscription;
  bool _isExecuting = false;
  int _retryCount = 0;
  static const _maxRetries = 3;

  LoginUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  Future<void> execute(LoginParams params) async {
    if (_isExecuting) return;
    _isExecuting = true;

    _events.add(OperationInProgress('login'));

    final validationError = params.validateWithMessage();
    if (validationError != null) {
      _events.add(OperationFailure('login', validationError));
      _isExecuting = false;
      return;
    }

    try {
      await _tokenSubscription?.cancel();
      _tokenSubscription = _repository.obtainToken(params.userSecret).listen(
        (token) {
          _events.add(TokenObtained(token, DateTime.now().add(Duration(hours: 1))));
          _isExecuting = false;
          _retryCount = 0;
        },
        onError: (error) {
          if (_retryCount < _maxRetries && _shouldRetry(error)) {
            _retryCount++;
            execute(params);
          } else {
            _events.add(OperationFailure('login', error.toString()));
            _isExecuting = false;
            _retryCount = 0;
          }
        },
      );
    } catch (e) {
      _events.add(OperationFailure('login', e.toString()));
      _isExecuting = false;
      _retryCount = 0;
    }
  }

  bool _shouldRetry(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') || 
           errorStr.contains('timeout') || 
           errorStr.contains('connection');
  }

  /// Get cached token if available
  Future<String?> getCachedToken() async {
    return _repository.currentToken;
  }

  @override
  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _events.close();
  }
} 