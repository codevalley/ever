import 'dart:async';

import '../../core/events.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Use case for retrieving the current authenticated user
/// 
/// Events:
/// - [UserRetrieved]: When user is successfully retrieved
/// - [UserNotFound]: When no authenticated user exists
/// - [OperationFailure]: When retrieval fails for other reasons
/// - [OperationInProgress]: When retrieval is in progress
class GetCurrentUserUseCase extends NoParamsUseCase {
  final UserRepository _repository;
  final _eventController = StreamController<DomainEvent>.broadcast();
  
  /// Whether a retrieval operation is in progress
  bool _isRetrieving = false;

  GetCurrentUserUseCase(this._repository) {
    // Listen to repository events and transform them if needed
    _repository.events.listen((event) {
      if (event is UserRetrieved) {
        _isRetrieving = false;
        _eventController.add(event);
      } else if (event is OperationFailure) {
        _isRetrieving = false;
        // Transform generic failure to user-specific failure if needed
        if (event.error.contains('not found') || 
            event.error.contains('no user') ||
            event.error.contains('unauthorized')) {
          _eventController.add(UserNotFound());
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
    if (_isRetrieving) return; // Prevent concurrent retrievals
    
    _isRetrieving = true;
    _repository.getCurrentUser();
  }

  @override
  void dispose() {
    _eventController.close();
  }
}
