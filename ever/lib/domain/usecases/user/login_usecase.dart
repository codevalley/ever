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

/// Use case for obtaining an access token
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
class ObtainTokenUseCase extends BaseUseCase<ObtainTokenParams> {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();
  StreamSubscription? _repositorySubscription;

  ObtainTokenUseCase(this._repository) {
    // Listen to repository events and forward relevant ones
    _repositorySubscription = _repository.events.listen(_eventController.add);
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute(ObtainTokenParams params) async {
    // Validate input parameters
    final validationError = params.validate();
    if (validationError != null) {
      _eventController.add(OperationFailure(
        'obtain_token',
        validationError,
      ));
      return;
    }

    try {
      await for (final token in _repository.obtainToken(params.userSecret)) {
        // Token obtained successfully, repository will emit appropriate events
      }
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
