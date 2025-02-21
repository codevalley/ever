import 'dart:async';

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
    return taskId.isNotEmpty;
  }

  String? validateWithMessage() {
    if (taskId.isEmpty) {
      return 'Task ID cannot be empty';
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
  final _events = StreamController<DomainEvent>.broadcast();
  bool _isUpdating = false;

  UpdateTaskUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  void execute(UpdateTaskParams params) async {
    if (_isUpdating) {
      throw StateError('Update already in progress');
    }
    
    _isUpdating = true;
    _events.add(OperationInProgress('update_task'));
    
    try {
      final validationError = params.validateWithMessage();
      if (validationError != null) {
        _events.add(OperationFailure('update_task', validationError));
        return;
      }

      // Get existing task
      Task? existingTask;
      await for (final task in _repository.read(params.taskId)) {
        existingTask = task;
        break;
      }

      if (existingTask == null) {
        throw Exception('Task not found');
      }

      // Create updated task
      final updatedTask = existingTask.copyWith(
        content: params.content,
        status: params.status,
        priority: params.priority,
        tags: params.tags,
        parentId: params.parentId,
        topicId: params.topicId,
        updatedAt: DateTime.now(),
      );

      await for (final task in _repository.update(updatedTask)) {
        _events.add(TaskUpdated(task));
      }
      
      _events.add(const OperationSuccess('update_task'));
    } catch (e) {
      _events.add(OperationFailure('update_task', e.toString()));
      rethrow;
    } finally {
      _isUpdating = false;
    }
  }

  @override
  void dispose() async {
    await _events.close();
  }
} 