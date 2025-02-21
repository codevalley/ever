import 'dart:async';

import '../../core/events.dart';
import '../../events/task_events.dart';
import '../../repositories/task_repository.dart';
import '../base_usecase.dart';

/// Parameters for listing tasks
class ListTasksParams {
  final Map<String, dynamic>? filters;

  const ListTasksParams({this.filters});

  bool validate() {
    return true; // No validation needed for now
  }

  String? validateWithMessage() {
    return null; // No validation needed for now
  }
}

/// Use case for listing tasks
/// 
/// Flow:
/// 1. Validates the filters if any
/// 2. Calls repository to list tasks with retries
/// 3. Emits appropriate events:
///    - [OperationInProgress]: When listing starts and on each retry
///    - [TasksRetrieved]: When tasks are retrieved successfully
///    - [OperationSuccess]: When listing completes successfully
///    - [OperationFailure]: When listing fails after all retries
class ListTasksUseCase extends BaseUseCase<ListTasksParams> {
  final TaskRepository _repository;
  final _events = StreamController<DomainEvent>.broadcast();
  bool _isListing = false;

  ListTasksUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  void execute(ListTasksParams params) async {
    if (_isListing) {
      throw StateError('Listing already in progress');
    }
    
    _isListing = true;
    _events.add(OperationInProgress('list_tasks'));
    
    try {
      final validationError = params.validateWithMessage();
      if (validationError != null) {
        _events.add(OperationFailure('list_tasks', validationError));
        return;
      }

      await for (final tasks in _repository.list(filters: params.filters)) {
        _events.add(TasksRetrieved(tasks));
      }
      
      _events.add(const OperationSuccess('list_tasks'));
    } catch (e) {
      _events.add(OperationFailure('list_tasks', e.toString()));
      rethrow;
    } finally {
      _isListing = false;
    }
  }

  @override
  void dispose() async {
    await _events.close();
  }
} 