import 'dart:async';

import '../../core/events.dart';
import '../../core/user_events.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Parameters for login use case
class LoginParams {
  final String username;
  final String password;

  LoginParams({
    required this.username,
    required this.password,
  });
}

/// Use case for user login
class LoginUseCase extends BaseUseCase<LoginParams> {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();

  LoginUseCase(this._repository) {
    // Listen to repository events and transform them if needed
    _repository.events.listen((event) {
      if (event is OperationInProgress) {
        _eventController.add(event);
      } else if (event is UserLoggedIn) {
        _eventController.add(event);
      } else if (event is AuthenticationFailed) {
        _eventController.add(event);
      }
      // Other events can be filtered or transformed here
    });
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute(LoginParams params) {
    _repository.authenticate(params.username, params.password);
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
