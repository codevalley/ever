import 'dart:async';

import '../../core/events.dart';
import '../../core/user_events.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Parameters for user registration
class RegisterParams {
  final String username;

  RegisterParams({
    required this.username,
  });
}

/// Use case for user registration
class RegisterUseCase extends BaseUseCase<RegisterParams> {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();

  RegisterUseCase(this._repository) {
    _repository.events.listen((event) {
      if (event is UserRegistered ||
          event is RegistrationFailed ||
          event is OperationInProgress) {
        _eventController.add(event);
      }
    });
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute(RegisterParams params) {
    _repository.register(params.username);
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
