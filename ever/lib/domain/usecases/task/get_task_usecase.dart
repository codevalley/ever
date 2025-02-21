import 'dart:async';

import 'package:rxdart/rxdart.dart';
import '../../core/events.dart';
import '../../events/task_events.dart';
import '../../repositories/task_repository.dart';
import '../base_usecase.dart';

/// Parameters for getting a task
class GetTaskParams {
  final String id;

  const GetTaskParams({required this.id});

  bool validate() {
    return id.isNotEmpty;
  }

  String? validateWithMessage() {
    if (id.isEmpty) {
      return 'Task ID cannot be empty';
    }
    return null;
  }
}

/// Use case for getting a single task by ID
/// 
/// Flow:
/// 1. Validates the task ID
/// 2. Calls repository to get task with retries
/// 3. Emits appropriate events:
///    - [OperationInProgress]: When retrieval starts and on each retry
///    - [TaskRetrieved]: When task is retrieved successfully
///    - [OperationSuccess]: When retrieval completes successfully
///    - [OperationFailure]: When retrieval fails after all retries
class GetTaskUseCase extends BaseUseCase<GetTaskParams> {
  final TaskRepository _repository;
  final _events = BehaviorSubject<DomainEvent>();
  bool _isRetrieving = false;
  static const _maxRetries = 3;

  GetTaskUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  void _addEvent(DomainEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  @override
  Future<void> execute(GetTaskParams params) async {
    if (_isRetrieving) {
      return;
    }

    _isRetrieving = true;
    _addEvent(OperationInProgress('get_task'));

    final validationError = params.validateWithMessage();
    if (validationError != null) {
      _addEvent(OperationFailure('get_task', validationError));
      _isRetrieving = false;
      return;
    }

    var retryCount = 0;
    Exception? lastError;

    while (retryCount <= _maxRetries) {
      try {
        await for (final task in _repository.read(params.id)) {
          _addEvent(TaskRetrieved(task));
          _addEvent(const OperationSuccess('get_task'));
          _isRetrieving = false;
          return;
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (retryCount < _maxRetries) {
          retryCount++;
          _addEvent(OperationInProgress('get_task'));
          await Future.delayed(Duration(milliseconds: retryCount * 100));
          continue;
        }
        break;
      }
    }

    _addEvent(OperationFailure('get_task', lastError.toString()));
    _isRetrieving = false;
    throw lastError!;
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
} 