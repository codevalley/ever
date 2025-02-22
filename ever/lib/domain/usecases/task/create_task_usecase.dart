import 'dart:async';

import '../../core/events.dart';
import '../../core/exceptions.dart';
import '../../entities/task.dart';
import '../../events/task_events.dart';
import '../../repositories/task_repository.dart';
import 'base_task_usecase.dart';

/// Parameters for creating a task
class CreateTaskParams {
  final String content;
  final TaskStatus status;
  final TaskPriority priority;
  final List<String>? tags;
  final String? parentId;
  final String? topicId;

  const CreateTaskParams({
    required this.content,
    required this.status,
    required this.priority,
    this.tags,
    this.parentId,
    this.topicId,
  });

  bool validate() {
    return content.isNotEmpty;
  }

  String? validateWithMessage() {
    if (content.isEmpty) {
      return 'Content cannot be empty';
    }
    return null;
  }
}

/// Use case for creating a task
class CreateTaskUseCase extends BaseTaskUseCase<CreateTaskParams> {
  final TaskRepository _repository;
  bool _isCreating = false;

  CreateTaskUseCase(this._repository);

  @override
  String get operationName => 'create_task';

  @override
  Future<void> execute(CreateTaskParams params) async {
    if (_isCreating) {
      throw StateError('Creation already in progress');
    }

    final validationError = params.validateWithMessage();
    if (validationError != null) {
      eventController.add(OperationInProgress(operationName));
      eventController.add(OperationFailure(operationName, validationError));
      throw TaskValidationException(validationError);
    }
    
    _isCreating = true;
    eventController.add(OperationInProgress(operationName));
    
    try {
      final task = Task(
        id: '', // Will be set by backend
        content: params.content,
        status: params.status,
        priority: params.priority,
        tags: params.tags ?? [],
        parentId: params.parentId,
        topicId: params.topicId,
        createdAt: DateTime.now(),
        processingStatus: ProcessingStatus.pending,
      );

      await for (final createdTask in _repository.create(task)) {
        eventController.add(TaskCreated(createdTask));
      }
      
      eventController.add(OperationSuccess(operationName));
    } catch (e) {
      final error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
      eventController.add(OperationFailure(operationName, error));
      if (e is DomainException) {
        rethrow;
      }
      throw TaskNetworkException(error);
    } finally {
      _isCreating = false;
    }
  }

  @override
  Future<void> dispose() async {
    await eventController.close();
  }
} 