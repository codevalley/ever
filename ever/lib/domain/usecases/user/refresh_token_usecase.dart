import 'dart:async';

import '../../core/events.dart';
import '../../core/user_events.dart';
import '../../entities/user.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Use case for managing token refresh and expiration
/// 
/// Responsibilities:
/// 1. Automatic token refresh before expiration
/// 2. Token expiration monitoring
/// 3. Warning emission before token expires
/// 
/// Events:
/// - [TokenExpiring]: Emitted when token is about to expire
/// - [TokenExpired]: Emitted when token has expired
/// - [TokenRefreshed]: Emitted when token is successfully refreshed
/// - [TokenRefreshFailed]: Emitted when token refresh fails
class RefreshTokenUseCase extends NoParamsUseCase {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();
  
  /// Timer for token expiration
  Timer? _expirationTimer;
  
  /// Timer for token expiration warning
  Timer? _warningTimer;
  
  /// Duration before expiry to emit warning
  static const warningThreshold = Duration(minutes: 5);
  
  /// Duration before expiry to attempt refresh
  static const refreshThreshold = Duration(minutes: 10);
  
  /// Whether a refresh operation is in progress
  bool _isRefreshing = false;

  RefreshTokenUseCase(this._repository) {
    // Listen to repository events and manage token lifecycle
    _repository.events.listen((event) {
      if (event is TokenObtained || event is TokenRefreshed) {
        _isRefreshing = false;
        _setupExpirationTimers(event.expiresAt);
        _eventController.add(event);
      } else if (event is OperationFailure) {
        _isRefreshing = false;
        _eventController.add(TokenRefreshFailed(event.error));
      } else if (event is TokenExpired || 
                event is TokenExpiring || 
                event is OperationInProgress) {
        _eventController.add(event);
      }
    });
  }

  /// Setup timers for token expiration and warning
  void _setupExpirationTimers(DateTime expiresAt) {
    // Cancel existing timers
    _expirationTimer?.cancel();
    _warningTimer?.cancel();

    final now = DateTime.now();
    final timeUntilExpiry = expiresAt.difference(now);

    // Don't set timers if token is already expired
    if (timeUntilExpiry.isNegative) {
      _eventController.add(TokenExpired());
      return;
    }

    // Set warning timer
    if (timeUntilExpiry > warningThreshold) {
      _warningTimer = Timer(
        timeUntilExpiry - warningThreshold,
        () {
          _eventController.add(TokenExpiring(warningThreshold));
          // Attempt refresh if not already in progress
          if (!_isRefreshing) {
            execute();
          }
        },
      );
    }

    // Set expiration timer
    _expirationTimer = Timer(
      timeUntilExpiry,
      () {
        _eventController.add(TokenExpired());
        // Clear timers as they're no longer needed
        _expirationTimer = null;
        _warningTimer = null;
      },
    );

    // If token is close to expiry, attempt refresh immediately
    if (timeUntilExpiry <= refreshThreshold && !_isRefreshing) {
      execute();
    }
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute([void params]) {
    if (_isRefreshing) return; // Prevent concurrent refreshes
    
    _isRefreshing = true;
    _repository.refreshToken();
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    _warningTimer?.cancel();
    _eventController.close();
  }
}
