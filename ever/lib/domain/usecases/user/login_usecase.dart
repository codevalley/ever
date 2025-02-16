import 'dart:async';

import '../../core/events.dart';
import '../../core/user_events.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Parameters for obtaining token
class ObtainTokenParams {
  final String userSecret;

  ObtainTokenParams({
    required this.userSecret,
  });
}

/// Use case for obtaining access token
class ObtainTokenUseCase extends BaseUseCase<ObtainTokenParams> {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();

  ObtainTokenUseCase(this._repository) {
    _repository.events.listen((event) {
      if (event is TokenObtained ||
          event is TokenAcquisitionFailed ||
          event is OperationInProgress) {
        _eventController.add(event);
      }
    });
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute(ObtainTokenParams params) {
    _repository.obtainToken(params.userSecret);
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
