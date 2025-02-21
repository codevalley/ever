import 'dart:async';

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

/// Use case for getting a task
class GetTaskUseCase extends BaseUseCase<GetTaskParams> {
  final TaskRepository _repository;
  final _events = StreamController<DomainEvent>.broadcast();
  bool _isRetrieving = false;

  GetTaskUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  void execute(GetTaskParams params) async {
    if (_isRetrieving) {
      throw StateError('Retrieval already in progress');
    }
    
    _isRetrieving = true;
    _events.add(OperationInProgress('get_task'));
    
    try {
      final validationError = params.validateWithMessage();
      if (validationError != null) {
        _events.add(OperationFailure('get_task', validationError));
        return;
      }

      await for (final task in _repository.read(params.id)) {
        _events.add(TaskRetrieved(task));
      }
      
      _events.add(const OperationSuccess('get_task'));
    } catch (e) {
      _events.add(OperationFailure('get_task', e.toString()));
      rethrow;
    } finally {
      _isRetrieving = false;
    }
  }

  @override
  void dispose() async {
    await _events.close();
  }
} 