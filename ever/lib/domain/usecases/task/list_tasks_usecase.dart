import 'dart:async';

import 'package:rxdart/rxdart.dart';
import '../../core/events.dart';
import '../../events/task_events.dart';
import '../../repositories/task_repository.dart';
import '../base_usecase.dart';

/// Parameters for listing tasks
class ListTasksParams {
  final Map<String, dynamic>? filters;

  const ListTasksParams({this.filters});

  bool validate() {
    // Add any validation logic if needed
    return true;
  }

  String? validateWithMessage() {
    // Add any validation messages if needed
    return null;
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
  final _events = BehaviorSubject<DomainEvent>();
  bool _isListing = false;
  static const _maxRetries = 3;

  ListTasksUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  void _addEvent(DomainEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  @override
  Future<void> execute(ListTasksParams params) async {
    if (_isListing) {
      return;
    }

    _isListing = true;
    _addEvent(OperationInProgress('list_tasks'));

    final validationError = params.validateWithMessage();
    if (validationError != null) {
      _addEvent(OperationFailure('list_tasks', validationError));
      _isListing = false;
      return;
    }

    var retryCount = 0;
    Exception? lastError;

    while (retryCount <= _maxRetries) {
      try {
        await for (final tasks in _repository.list(filters: params.filters)) {
          _addEvent(TasksRetrieved(tasks));
          _addEvent(const OperationSuccess('list_tasks'));
          _isListing = false;
          return;
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (retryCount < _maxRetries) {
          retryCount++;
          _addEvent(OperationInProgress('list_tasks'));
          await Future.delayed(Duration(milliseconds: retryCount * 100));
          continue;
        }
        break;
      }
    }

    _addEvent(OperationFailure('list_tasks', lastError.toString()));
    _isListing = false;
    throw lastError!;
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
} 