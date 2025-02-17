import 'dart:async';

import '../../core/events.dart';
import '../../core/user_events.dart';
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
///    - [UserRegistered]: When registration succeeds with user info and secret
///    - [OperationFailure]: When validation or registration fails
class RegisterUseCase extends BaseUseCase<RegisterParams> {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();
  StreamSubscription? _repositorySubscription;

  RegisterUseCase(this._repository) {
    // Listen to repository events and forward them
    _repositorySubscription = _repository.events.listen(_eventController.add);
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute(RegisterParams params) async {
    // Validate input parameters
    final validationError = params.validate();
    if (validationError != null) {
      _eventController.add(OperationFailure(
        'register',
        validationError,
      ));
      return;
    }

    try {
      // We don't need the user value since repository emits events
      await _repository.register(params.username.trim()).drain<void>();
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
