import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/user_events.dart';
import 'package:ever/domain/entities/user.dart';
import 'package:ever/domain/repositories/user_repository.dart';
import 'package:ever/domain/usecases/base_usecase.dart';

/// Use case for retrieving the current authenticated user
/// 
/// Events:
/// - [CurrentUserRetrieved]: When user is successfully retrieved
/// - [OperationFailure]: When retrieval fails for other reasons
/// - [OperationInProgress]: When retrieval is in progress
class GetCurrentUserUseCase extends NoParamsUseCase {
  final UserRepository _repository;
  final _events = StreamController<DomainEvent>.broadcast();
  StreamSubscription<User>? _userSubscription;
  bool _isExecuting = false;

  GetCurrentUserUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  Future<void> execute([void params]) async {
    if (_isExecuting) return;
    _isExecuting = true;

    try {
      _events.add(OperationInProgress('get_current_user'));
      await _userSubscription?.cancel();
      _userSubscription = _repository.getCurrentUser().listen(
        (user) {
          _events.add(CurrentUserRetrieved(user));
          _isExecuting = false;
        },
        onError: (error) {
          final errorStr = error.toString().toLowerCase();
          if (errorStr.contains('not found') ||
              errorStr.contains('no user') ||
              errorStr.contains('unauthorized') ||
              errorStr.contains('token expired')) {
            _events.add(CurrentUserRetrieved(null));
          } else {
            _events.add(OperationFailure('get_current_user', error.toString()));
          }
          _isExecuting = false;
        },
      );
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('not found') ||
          errorStr.contains('no user') ||
          errorStr.contains('unauthorized') ||
          errorStr.contains('token expired')) {
        _events.add(CurrentUserRetrieved(null));
      } else {
        _events.add(OperationFailure('get_current_user', e.toString()));
      }
      _isExecuting = false;
    }
  }

  @override
  Future<void> dispose() async {
    await _userSubscription?.cancel();
    await _events.close();
  }
}
