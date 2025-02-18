import 'dart:async';

import '../../core/events.dart';
import '../../core/user_events.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Parameters for login operation
class LoginParams {
  /// User secret obtained during registration
  /// Used to obtain new access tokens
  final String userSecret;

  const LoginParams({
    required this.userSecret,
  });

  /// Validate login parameters
  String? validate() {
    final trimmed = userSecret.trim();
    if (trimmed.isEmpty) {
      return 'User secret cannot be empty';
    }
    if (trimmed.length < 8) {
      return 'User secret must be at least 8 characters';
    }
    // Basic format validation - should contain at least one letter and one number
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(trimmed)) {
      return 'User secret must contain at least one letter and one number';
    }
    return null;
  }
}

/// Use case for user login
/// 
/// Flow:
/// 1. Validates the user secret
/// 2. Calls repository to obtain token
/// 3. Emits appropriate events:
///    - [OperationInProgress]: When token acquisition starts
///    - [TokenObtained]: When token is obtained successfully
///    - [OperationFailure]: When validation or token acquisition fails
///    - [TokenExpiring]: When token is about to expire
///    - [TokenExpired]: When token has expired
class LoginUseCase extends BaseUseCase<LoginParams> {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();
  StreamSubscription? _repositorySubscription;

  LoginUseCase(this._repository) {
    // Listen to repository events and forward relevant ones
    _repositorySubscription = _repository.events.listen(_eventController.add);
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute(LoginParams params) async {
    // Validate input parameters
    final validationError = params.validate();
    if (validationError != null) {
      _eventController.add(OperationFailure(
        'login',
        validationError,
      ));
      return;
    }

    try {
      // We don't need the token value since repository emits events
      await _repository.obtainToken(params.userSecret).drain<void>();
    } catch (e) {
      // Repository will emit appropriate failure events
    }
  }

  @override
  void dispose() {
    _repositorySubscription?.cancel();
    _eventController.close();
  }
}
