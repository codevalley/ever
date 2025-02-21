import 'dart:async';

import 'package:rxdart/rxdart.dart';
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
  final _events = BehaviorSubject<DomainEvent>();
  bool _isDeleting = false;
  static const _maxRetries = 3;

  DeleteTaskUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  void _addEvent(DomainEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  @override
  Future<void> execute(DeleteTaskParams params) async {
    if (_isDeleting) {
      return;
    }

    _isDeleting = true;
    _addEvent(OperationInProgress('delete_task'));

    final validationError = params.validateWithMessage();
    if (validationError != null) {
      _addEvent(OperationFailure('delete_task', validationError));
      _isDeleting = false;
      return;
    }

    var retryCount = 0;
    Exception? lastError;

    while (retryCount <= _maxRetries) {
      try {
        await for (final _ in _repository.delete(params.taskId)) {
          _addEvent(TaskDeleted(params.taskId));
          _addEvent(const OperationSuccess('delete_task'));
          _isDeleting = false;
          return;
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (retryCount < _maxRetries) {
          retryCount++;
          _addEvent(OperationInProgress('delete_task'));
          await Future.delayed(Duration(milliseconds: retryCount * 100));
          continue;
        }
        break;
      }
    }

    _addEvent(OperationFailure('delete_task', lastError.toString()));
    _isDeleting = false;
    throw lastError!;
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
} 