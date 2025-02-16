import 'dart:async';

import '../../core/events.dart';
import '../../core/user_events.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Parameters for user registration
class RegisterParams {
  /// Username for registration
  /// Must be non-empty and contain only valid characters
  final String username;

  const RegisterParams({
    required this.username,
  });

  /// Validate registration parameters
  String? validate() {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      return 'Username cannot be empty';
    }
    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }
}

/// Use case for user registration
/// 
/// Flow:
/// 1. Validates the username
/// 2. Calls repository to register user
/// 3. Emits appropriate events:
///    - [OperationInProgress]: When registration starts
///    - [UserRegistered]: When registration succeeds
///    - [RegistrationFailed]: When validation or registration fails
class RegisterUseCase extends BaseUseCase<RegisterParams> {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();

  RegisterUseCase(this._repository) {
    // Listen to repository events and transform them if needed
    _repository.events.listen((event) {
      if (event is UserRegistered) {
        // Repository provides domain User object, forward as is
        _eventController.add(event);
      } else if (event is OperationFailure) {
        // Transform generic failure to registration-specific failure
        _eventController.add(RegistrationFailed(event.error));
      } else if (event is OperationInProgress) {
        _eventController.add(event);
      }
    });
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute(RegisterParams params) {
    // Validate input parameters
    final validationError = params.validate();
    if (validationError != null) {
      _eventController.add(RegistrationFailed(validationError));
      return;
    }

    // Proceed with registration
    _repository.register(params.username.trim());
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
