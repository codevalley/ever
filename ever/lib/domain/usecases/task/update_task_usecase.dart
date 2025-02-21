import 'dart:async';

import 'package:rxdart/rxdart.dart';
import '../../core/events.dart';
import '../../events/task_events.dart';
import '../../entities/task.dart';
import '../../repositories/task_repository.dart';
import '../base_usecase.dart';

/// Parameters for updating a task
class UpdateTaskParams {
  final String taskId;
  final String? content;
  final TaskStatus? status;
  final TaskPriority? priority;
  final List<String>? tags;
  final String? parentId;
  final String? topicId;

  const UpdateTaskParams({
    required this.taskId,
    this.content,
    this.status,
    this.priority,
    this.tags,
    this.parentId,
    this.topicId,
  });

  bool validate() {
    return taskId.isNotEmpty && (content?.isNotEmpty ?? true);
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
/// 4. Saves the updated task with retries
/// 5. Emits appropriate events:
///    - [OperationInProgress]: When update starts and on each retry
///    - [TaskUpdated]: When task is updated successfully
///    - [OperationSuccess]: When update completes successfully
///    - [OperationFailure]: When update fails after all retries
class UpdateTaskUseCase extends BaseUseCase<UpdateTaskParams> {
  final TaskRepository _repository;
  final _events = BehaviorSubject<DomainEvent>();
  bool _isUpdating = false;
  static const _maxRetries = 3;

  UpdateTaskUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  void _addEvent(DomainEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  @override
  Future<void> execute(UpdateTaskParams params) async {
    if (_isUpdating) {
      return;
    }

    _isUpdating = true;
    _addEvent(OperationInProgress('update_task'));

    final validationError = params.validateWithMessage();
    if (validationError != null) {
      _addEvent(OperationFailure('update_task', validationError));
      _isUpdating = false;
      return;
    }

    Task? existingTask;
    var retryCount = 0;
    Exception? lastError;

    // First, try to get the existing task
    while (retryCount <= _maxRetries) {
      try {
        await for (final task in _repository.read(params.taskId)) {
          existingTask = task;
          break;
        }
        break;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (retryCount < _maxRetries) {
          retryCount++;
          _addEvent(OperationInProgress('update_task'));
          await Future.delayed(Duration(milliseconds: retryCount * 100));
          continue;
        }
        _addEvent(OperationFailure('update_task', lastError.toString()));
        _isUpdating = false;
        throw lastError;
      }
    }

    if (existingTask == null) {
      const error = 'Failed to retrieve existing task';
      _addEvent(OperationFailure('update_task', error));
      _isUpdating = false;
      throw Exception(error);
    }

    // Reset retry count for update operation
    retryCount = 0;
    lastError = null;

    // Create updated task
    final updatedTask = Task(
      id: existingTask.id,
      content: params.content ?? existingTask.content,
      status: params.status ?? existingTask.status,
      priority: params.priority ?? existingTask.priority,
      tags: params.tags ?? existingTask.tags,
      parentId: params.parentId ?? existingTask.parentId,
      topicId: params.topicId ?? existingTask.topicId,
      createdAt: existingTask.createdAt,
      updatedAt: DateTime.now(),
      processingStatus: existingTask.processingStatus,
    );

    // Try to update the task
    while (retryCount <= _maxRetries) {
      try {
        await for (final task in _repository.update(updatedTask)) {
          _addEvent(TaskUpdated(task));
          _addEvent(const OperationSuccess('update_task'));
          _isUpdating = false;
          return;
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (retryCount < _maxRetries) {
          retryCount++;
          _addEvent(OperationInProgress('update_task'));
          await Future.delayed(Duration(milliseconds: retryCount * 100));
          continue;
        }
        break;
      }
    }

    _addEvent(OperationFailure('update_task', lastError.toString()));
    _isUpdating = false;
    throw lastError!;
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
} 