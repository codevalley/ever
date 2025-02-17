import 'dart:async';

import '../../core/events.dart';
import '../../core/user_events.dart';
import '../../repositories/user_repository.dart';
import '../base_usecase.dart';

/// Use case for retrieving the current authenticated user
/// 
/// Events:
/// - [CurrentUserRetrieved]: When user is successfully retrieved
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
      if (event is CurrentUserRetrieved) {
        _isRetrieving = false;
        _eventController.add(event);
      } else if (event is OperationFailure) {
        _isRetrieving = false;
        // Transform generic failure to user-specific failure if needed
        final error = event.error.toLowerCase();
        if (error.contains('not found') || 
            error.contains('no user') ||
            error.contains('unauthorized')) {
          // If user is not found or unauthorized, consider it a normal case
          _eventController.add(const CurrentUserRetrieved(null));
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
