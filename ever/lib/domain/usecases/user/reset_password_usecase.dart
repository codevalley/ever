import 'dart:async';

import '../../core/events.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Parameters for requesting password reset
class RequestPasswordResetParams {
  final String email;

  RequestPasswordResetParams({required this.email});
}

/// Parameters for completing password reset
class CompletePasswordResetParams {
  final String token;
  final String newPassword;

  CompletePasswordResetParams({
    required this.token,
    required this.newPassword,
  });
}

/// Use case for password reset flow
class ResetPasswordUseCase extends BaseUseCase<RequestPasswordResetParams> {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();

  ResetPasswordUseCase(this._repository) {
    _repository.events.listen((event) {
      if (event is PasswordResetRequested ||
          event is PasswordResetCompleted ||
          event is PasswordResetFailed ||
          event is OperationInProgress) {
        _eventController.add(event);
      }
    });
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute(RequestPasswordResetParams params) {
    _repository.requestPasswordReset(params.email);
  }

  /// Complete the password reset process
  void completeReset(CompletePasswordResetParams params) {
    _repository.completePasswordReset(
      token: params.token,
      newPassword: params.newPassword,
    );
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
