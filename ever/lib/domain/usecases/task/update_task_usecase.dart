import 'dart:async';

import '../../core/events.dart';
import '../../core/exceptions.dart';
import '../../events/task_events.dart';
import '../../entities/task.dart';
import '../../repositories/task_repository.dart';
import 'base_task_usecase.dart';

/// Parameters for updating a task
class UpdateTaskParams {
  final String taskId;
  final String? content;
  final TaskStatus? status;
  final TaskPriority? priority;
  final List<String>? tags;
  final String? parentId;
  final String? topicId;
  final DateTime? dueDate;

  const UpdateTaskParams({
    required this.taskId,
    this.content,
    this.status,
    this.priority,
    this.tags,
    this.parentId,
    this.topicId,
    this.dueDate,
  });

  bool validate() {
    if (taskId.isEmpty) return false;
    if (content != null && content!.isEmpty) return false;
    return true;
  }

  String? validateWithMessage() {
    if (taskId.isEmpty) {
      return 'Task ID cannot be empty';
    }
    if (content != null && content!.isEmpty) {
      return 'Content cannot be empty if provided';
    }
    return null;
  }
}

/// Use case for updating a task
/// 
/// Flow:
/// 1. Validates the task ID and content
/// 2. Retrieves the existing task
/// 3. Updates the task with new values
/// 4. Saves the updated task
/// 5. Emits appropriate events:
///    - [OperationInProgress]: When update starts
///    - [TaskUpdated]: When task is updated successfully
///    - [OperationSuccess]: When update completes successfully
///    - [OperationFailure]: When update fails
class UpdateTaskUseCase extends BaseTaskUseCase<UpdateTaskParams> {
  final TaskRepository _repository;
  bool _isUpdating = false;

  UpdateTaskUseCase(this._repository);

  @override
  String get operationName => 'update_task';

  @override
  bool get isOperationInProgress => _isUpdating;

  @override
  Future<void> execute(UpdateTaskParams params) async {
    if (_isUpdating) {
      throw StateError('Update already in progress');
    }

    final validationError = params.validateWithMessage();
    if (validationError != null) {
      eventController.add(OperationInProgress(operationName));
      eventController.add(OperationFailure(operationName, validationError));
      throw StateError(validationError);
    }
    
    _isUpdating = true;
    eventController.add(OperationInProgress(operationName));
    
    try {
      // First get the existing task
      Task? existingTask;
      await for (final task in _repository.read(params.taskId)) {
        existingTask = task;
        break;
      }

      if (existingTask == null) {
        eventController.add(OperationFailure(operationName, 'Task not found'));
        throw StateError('Task not found');
      }

      // Create updated task with new values
      final updatedTask = Task(
        id: params.taskId,
        content: params.content ?? existingTask.content,
        status: params.status ?? existingTask.status,
        priority: params.priority ?? existingTask.priority,
        dueDate: params.dueDate ?? existingTask.dueDate,
        tags: params.tags ?? existingTask.tags,
        parentId: params.parentId ?? existingTask.parentId,
        topicId: params.topicId ?? existingTask.topicId,
        createdAt: existingTask.createdAt,
        updatedAt: DateTime.now(),
        processingStatus: existingTask.processingStatus,
      );

      // Update task
      await for (final task in _repository.update(updatedTask)) {
        eventController.add(TaskUpdated(task));
        eventController.add(OperationSuccess(operationName));
        return;
      }
    } catch (e) {
      if (e is TaskNotFoundException) {
        eventController.add(OperationFailure(operationName, 'Task not found'));
        throw StateError('Task not found');
      }
      final error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
      eventController.add(OperationFailure(operationName, error));
      if (e is DomainException) {
        rethrow;
      }
      throw TaskNetworkException(error);
    } finally {
      _isUpdating = false;
    }
  }
} 