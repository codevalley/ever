import 'dart:async';

import '../../core/events.dart';
import '../../events/task_events.dart';
import '../../repositories/task_repository.dart';
import '../base_usecase.dart';

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
class DeleteTaskUseCase extends BaseUseCase<DeleteTaskParams> {
  final TaskRepository _repository;
  final _events = StreamController<DomainEvent>.broadcast();
  bool _isDeleting = false;

  DeleteTaskUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  void execute(DeleteTaskParams params) async {
    if (_isDeleting) {
      throw StateError('Deletion already in progress');
    }
    
    _isDeleting = true;
    _events.add(OperationInProgress('delete_task'));
    
    try {
      final validationError = params.validateWithMessage();
      if (validationError != null) {
        _events.add(OperationFailure('delete_task', validationError));
        return;
      }

      await _repository.delete(params.taskId).drain<void>();
      _events.add(TaskDeleted(params.taskId));
      _events.add(const OperationSuccess('delete_task'));
    } catch (e) {
      _events.add(OperationFailure('delete_task', e.toString()));
      rethrow;
    } finally {
      _isDeleting = false;
    }
  }

  @override
  void dispose() async {
    await _events.close();
  }
} 