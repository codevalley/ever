import 'dart:async';

import '../../core/events.dart';
import '../../core/user_events.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Use case for refreshing access token
class RefreshTokenUseCase extends NoParamsUseCase {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();
  Timer? _expirationTimer;
  Timer? _warningTimer;

  RefreshTokenUseCase(this._repository) {
    _repository.events.listen((event) {
      if (event is TokenObtained || event is TokenRefreshed) {
        _setupExpirationTimers(event.expiresAt);
        _eventController.add(event);
      } else if (event is TokenRefreshFailed ||
          event is TokenExpired ||
          event is TokenExpiring ||
          event is OperationInProgress) {
        _eventController.add(event);
      }
    });
  }

  void _setupExpirationTimers(DateTime expiresAt) {
    // Cancel existing timers
    _expirationTimer?.cancel();
    _warningTimer?.cancel();

    final now = DateTime.now();
    final timeUntilExpiry = expiresAt.difference(now);
    
    // Set warning timer 5 minutes before expiration
    if (timeUntilExpiry > const Duration(minutes: 5)) {
      _warningTimer = Timer(
        timeUntilExpiry - const Duration(minutes: 5),
        () => _eventController.add(TokenExpiring(const Duration(minutes: 5))),
      );
    }

    // Set expiration timer
    _expirationTimer = Timer(
      timeUntilExpiry,
      () => _eventController.add(TokenExpired()),
    );
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute([void params]) {
    if (_repository.currentUserSecret != null) {
      _repository.refreshToken();
    } else {
      _eventController.add(
        TokenRefreshFailed('No user secret available for token refresh'),
      );
    }
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    _warningTimer?.cancel();
    _eventController.close();
  }
}
