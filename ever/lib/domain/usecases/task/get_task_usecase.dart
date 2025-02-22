import 'dart:async';

import '../../core/events.dart';
import '../../core/exceptions.dart';
import '../../events/task_events.dart';
import '../../entities/task.dart';
import '../../repositories/task_repository.dart';
import 'base_task_usecase.dart';

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
///    - [OperationInProgress]: When retrieval starts
///    - [TaskRetrieved]: When task is retrieved successfully
///    - [OperationSuccess]: When retrieval completes successfully
///    - [OperationFailure]: When retrieval fails
class GetTaskUseCase extends BaseTaskUseCase<GetTaskParams> {
  final TaskRepository _repository;
  final _taskController = StreamController<Task>.broadcast();
  bool _isExecuting = false;

  GetTaskUseCase(this._repository);

  @override
  String get operationName => 'get_task';

  /// Stream of the task
  Stream<Task> get task => _taskController.stream;

  @override
  Future<void> execute([GetTaskParams? params]) async {
    if (_isExecuting) {
      throw StateError('Task retrieval already in progress');
    }
    if (params == null) {
      handleValidationError('Task ID is required');
    }

    final validationError = params!.validateWithMessage();
    if (validationError != null) {
      eventController.add(OperationInProgress(operationName));
      eventController.add(OperationFailure(operationName, validationError));
      throw TaskValidationException(validationError);
    }

    _isExecuting = true;
    eventController.add(OperationInProgress(operationName));
    
    try {
      var taskFound = false;
      await for (final task in _repository.read(params.id)) {
        taskFound = true;
        _taskController.add(task);
        eventController.add(TaskRetrieved(task));
        eventController.add(OperationSuccess(operationName));
        return;
      }
      
      // If we get here, no task was found
      if (!taskFound) {
        throw TaskNotFoundException(params.id);
      }
    } catch (e) {
      if (e is TaskNotFoundException) {
        eventController.add(OperationFailure(operationName, 'Task not found'));
        rethrow;
      }
      final error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
      eventController.add(OperationFailure(operationName, error));
      if (e is DomainException) {
        rethrow;
      }
      throw TaskNetworkException(error);
    } finally {
      _isExecuting = false;
    }
  }

  @override
  Future<void> dispose() async {
    if (!_taskController.isClosed) {
      await _taskController.close();
    }
    await super.dispose();
  }
} 