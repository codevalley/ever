import 'dart:async';

import '../../core/events.dart';
import '../../core/user_events.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Parameters for obtaining an access token
class ObtainTokenParams {
  /// User secret obtained during registration
  /// Used to obtain new access tokens
  final String userSecret;

  const ObtainTokenParams({
    required this.userSecret,
  });

  /// Validate token parameters
  String? validate() {
    final trimmed = userSecret.trim();
    if (trimmed.isEmpty) {
      return 'User secret cannot be empty';
    }
    // Add more validation if needed based on user secret format
    return null;
  }
}

/// Use case for obtaining an access token
/// 
/// Flow:
/// 1. Validates the user secret
/// 2. Calls repository to obtain token
/// 3. Emits appropriate events:
///    - [OperationInProgress]: When token acquisition starts
///    - [TokenObtained]: When token is obtained successfully
///    - [TokenAcquisitionFailed]: When validation or token acquisition fails
///    - [TokenExpiring]: When token is about to expire (via RefreshTokenUseCase)
///    - [TokenExpired]: When token has expired (via RefreshTokenUseCase)
class ObtainTokenUseCase extends BaseUseCase<ObtainTokenParams> {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();

  ObtainTokenUseCase(this._repository) {
    // Listen to repository events and transform them if needed
    _repository.events.listen((event) {
      if (event is TokenObtained) {
        // Forward token events as is
        _eventController.add(event);
      } else if (event is OperationFailure) {
        // Transform generic failure to token-specific failure
        _eventController.add(TokenAcquisitionFailed(event.error));
      } else if (event is OperationInProgress) {
        _eventController.add(event);
      }
    });
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute(ObtainTokenParams params) {
    // Validate input parameters
    final validationError = params.validate();
    if (validationError != null) {
      _eventController.add(TokenAcquisitionFailed(validationError));
      return;
    }

    // Proceed with token acquisition
    _repository.obtainToken(params.userSecret.trim());
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
