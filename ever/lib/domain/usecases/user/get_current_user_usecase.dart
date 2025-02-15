import 'dart:async';

import '../../core/events.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Use case to get current user
class GetCurrentUserUseCase extends NoParamsUseCase {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();

  GetCurrentUserUseCase(this._repository) {
    // Listen to repository events
    _repository.events.listen((event) {
      // Forward relevant events
      _eventController.add(event);
    });
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute([void params]) {
    _repository.getCurrentUser();
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
