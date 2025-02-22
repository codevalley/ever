import 'dart:async';

import '../../core/events.dart';
import '../../core/exceptions.dart';
import '../../events/task_events.dart';
import '../../repositories/task_repository.dart';
import 'base_task_usecase.dart';

/// Parameters for deleting a task
class DeleteTaskParams {
  final String taskId;

  const DeleteTaskParams({required this.taskId});

  bool validate() {
    return taskId.isNotEmpty;
  }

  String? validateWithMessage() {
    if (taskId.isEmpty) {
      return 'Task ID cannot be empty';
    }
    return null;
  }
}

/// Use case for deleting a task
class DeleteTaskUseCase extends BaseTaskUseCase<DeleteTaskParams> {
  final TaskRepository _repository;
  static const _maxRetries = 3;
  bool _isDeleting = false;

  DeleteTaskUseCase(this._repository);

  @override
  String get operationName => 'delete_task';

  @override
  bool get isOperationInProgress => _isDeleting;

  @override
  Future<void> execute(DeleteTaskParams params) async {
    if (_isDeleting) {
      throw StateError('Task deletion already in progress');
    }

    final validationError = params.validateWithMessage();
    if (validationError != null) {
      eventController.add(OperationInProgress(operationName));
      eventController.add(OperationFailure(operationName, validationError));
      throw StateError(validationError);
    }

    _isDeleting = true;
    int retryCount = 0;
    eventController.add(OperationInProgress(operationName));

    try {
      while (retryCount < _maxRetries) {
        try {
          await for (final _ in _repository.delete(params.taskId)) {
            // Do nothing, just consume the stream
          }
          eventController.add(TaskDeleted(params.taskId));
          eventController.add(OperationSuccess(operationName));
          return;
        } catch (e) {
          if (e is TaskNotFoundException) {
            eventController.add(OperationFailure(operationName, 'Task not found'));
            throw StateError('Task not found');
          }
          if (retryCount < _maxRetries - 1 && _shouldRetry(e)) {
            retryCount++;
            await Future.delayed(Duration(milliseconds: 100 * retryCount));
            eventController.add(OperationInProgress(operationName));
            continue;
          }
          eventController.add(OperationFailure(operationName, 'Network error'));
          throw TaskNetworkException('Network error');
        }
      }
    } finally {
      _isDeleting = false;
    }
  }

  bool _shouldRetry(dynamic error) {
    if (error is TaskNotFoundException) return false;
    if (error is TaskValidationException) return false;
    if (error is TaskConcurrencyException) return false;
    
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') || 
           errorStr.contains('timeout') || 
           errorStr.contains('connection');
  }
} 