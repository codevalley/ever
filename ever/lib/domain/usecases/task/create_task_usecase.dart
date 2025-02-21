import 'dart:async';

import '../../core/events.dart';
import '../../entities/task.dart';
import '../../events/task_events.dart';
import '../../repositories/task_repository.dart';
import '../base_usecase.dart';

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
      return 'Task content cannot be empty';
    }
    return null;
  }
}

/// Use case for creating a task
class CreateTaskUseCase extends BaseUseCase<CreateTaskParams> {
  final TaskRepository _repository;
  final _events = StreamController<DomainEvent>.broadcast();
  bool _isCreating = false;

  CreateTaskUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  void execute(CreateTaskParams params) async {
    if (_isCreating) {
      throw StateError('Creation already in progress');
    }
    
    _isCreating = true;
    _events.add(OperationInProgress('create_task'));
    
    try {
      final validationError = params.validateWithMessage();
      if (validationError != null) {
        _events.add(OperationFailure('create_task', validationError));
        return;
      }

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
        _events.add(TaskCreated(createdTask));
      }
      
      _events.add(const OperationSuccess('create_task'));
    } catch (e) {
      _events.add(OperationFailure('create_task', e.toString()));
      rethrow;
    } finally {
      _isCreating = false;
    }
  }

  @override
  void dispose() async {
    await _events.close();
  }
} 