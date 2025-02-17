import 'dart:async';

import '../../core/events.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Use case for signing out the current user
/// 
/// Responsibilities:
/// 1. Clear user tokens and credentials
/// 2. Clean up any user-specific data
/// 3. Notify system of user sign out
/// 
/// Events:
/// - [UserSignedOut]: When sign out is successful
/// - [OperationFailure]: When sign out fails
/// - [OperationInProgress]: When sign out is in progress
class SignOutUseCase extends NoParamsUseCase {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();
  
  /// Whether a sign out operation is in progress
  bool _isSigningOut = false;

  SignOutUseCase(this._repository) {
    // Listen to repository events and transform them if needed
    _repository.events.listen((event) {
      if (event is UserSignedOut) {
        _isSigningOut = false;
        _eventController.add(event);
      } else if (event is OperationFailure) {
        _isSigningOut = false;
        // Transform generic failure to sign-out specific failure if needed
        final error = event.error.toLowerCase();
        if (error.contains('already signed out') || 
            error.contains('no user') ||
            error.contains('unauthorized')) {
          // If user is already signed out or not found, consider it a success
          _eventController.add(UserSignedOut());
        } else {
          _eventController.add(event);
        }
      } else if (event is OperationInProgress) {
        _eventController.add(event);
      }
    });
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  void execute([void params]) {
    if (_isSigningOut) return; // Prevent concurrent sign outs
    
    _isSigningOut = true;
    _repository.signOut();
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
