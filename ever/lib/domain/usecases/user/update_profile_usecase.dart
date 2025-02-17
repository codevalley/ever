import 'dart:async';

import '../../core/events.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Parameters for updating user profile
class UpdateProfileParams {
  final User user;

  UpdateProfileParams({required this.user});
}

/// Use case for updating user profile
class UpdateProfileUseCase extends BaseUseCase<UpdateProfileParams> {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();

  UpdateProfileUseCase(this._repository) {
    _repository.events.listen((event) {
      if (event is UserProfileUpdated ||
          event is OperationInProgress ||
          event is OperationFailure) {
        _eventController.add(event);
      }
    });
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute(UpdateProfileParams params) {
    _repository.updateProfile(params.user);
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
