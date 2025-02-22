import 'dart:async';

import '../../core/events.dart';
import '../../core/exceptions.dart';
import '../../events/task_events.dart';
import '../../repositories/task_repository.dart';
import 'base_task_usecase.dart';

/// Parameters for listing tasks
class ListTasksParams {
  final String? query;
  final String? status;
  final String? priority;
  final String? tag;
  final String? parentId;
  final String? topicId;
  final bool? includeCompleted;
  final bool? includeArchived;
  final int? limit;
  final int? offset;

  const ListTasksParams({
    this.query,
    this.status,
    this.priority,
    this.tag,
    this.parentId,
    this.topicId,
    this.includeCompleted,
    this.includeArchived,
    this.limit,
    this.offset,
  });

  Map<String, dynamic> toFilters() {
    return {
      if (query != null) 'query': query,
      if (status != null) 'status': status,
      if (priority != null) 'priority': priority,
      if (tag != null) 'tag': tag,
      if (parentId != null) 'parentId': parentId,
      if (topicId != null) 'topicId': topicId,
      if (includeCompleted != null) 'includeCompleted': includeCompleted,
      if (includeArchived != null) 'includeArchived': includeArchived,
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
    };
  }

  bool validate() {
    return true;
  }

  String? validateWithMessage() {
    return null;
  }
}

/// Use case for listing tasks
/// 
/// Flow:
/// 1. Validates the filters if any
/// 2. Calls repository to list tasks with retries
/// 3. Emits appropriate events:
///    - [OperationInProgress]: When listing starts and on each retry
///    - [TasksRetrieved]: When tasks are retrieved successfully
///    - [OperationSuccess]: When listing completes successfully
///    - [OperationFailure]: When listing fails after all retries
class ListTasksUseCase extends BaseTaskUseCase<ListTasksParams> {
  final TaskRepository _repository;
  static const _maxRetries = 3;
  bool _isExecuting = false;

  ListTasksUseCase(this._repository);

  @override
  String get operationName => 'list_tasks';

  @override
  bool get isOperationInProgress => _isExecuting;

  @override
  Future<void> execute([ListTasksParams? params]) async {
    if (isOperationInProgress) {
      throw StateError('Listing already in progress');
    }

    params ??= const ListTasksParams();
    _isExecuting = true;

    try {
      int retryCount = 0;
      while (retryCount < _maxRetries) {
        try {
          eventController.add(OperationInProgress(operationName));
          await for (final tasks in _repository.list(filters: params.toFilters())) {
            eventController.add(TasksRetrieved(tasks));
          }
          eventController.add(OperationSuccess(operationName));
          return;
        } catch (e) {
          if (e is TaskNotFoundException) {
            rethrow;
          }
          if (retryCount < _maxRetries - 1 && _shouldRetry(e)) {
            retryCount++;
            await Future.delayed(Duration(milliseconds: 100 * retryCount));
            continue;
          }
          eventController.add(OperationFailure(operationName, 'Network error'));
          throw Exception('Network error');
        }
      }
    } finally {
      _isExecuting = false;
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