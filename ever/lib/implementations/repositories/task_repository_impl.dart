import 'dart:async';

import '../../core/logging.dart';
import '../../domain/core/circuit_breaker.dart';
import '../../domain/core/events.dart';
import '../../domain/core/retry_config.dart';
import '../../domain/core/retry_events.dart';
import '../../domain/datasources/task_ds.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/task_repository.dart';

/// Implementation of TaskRepository with resilience patterns
class TaskRepositoryImpl implements TaskRepository {
  final TaskDataSource _dataSource;
  final CircuitBreaker _circuitBreaker;
  final RetryConfig _retryConfig;
  final _eventController = StreamController<DomainEvent>.broadcast();
  StreamSubscription? _dataSourceSubscription;

  TaskRepositoryImpl(
    this._dataSource, {
    CircuitBreaker? circuitBreaker,
    RetryConfig? retryConfig,
  })  : _circuitBreaker = circuitBreaker ?? CircuitBreaker(),
        _retryConfig = retryConfig ?? RetryConfig.defaultConfig {
    _dataSourceSubscription = _dataSource.events.listen(_handleDataSourceEvent);
  }

  /// Handle events from the data source
  void _handleDataSourceEvent(DomainEvent event) {
    // Transform or forward events as needed
    if (event is OperationInProgress ||
        event is OperationSuccess ||
        event is OperationFailure ||
        event is RetryAttempt ||
        event is RetrySuccess ||
        event is RetryExhausted) {
      _eventController.add(event);
    } else {
      // Forward domain events directly
      _eventController.add(event);
    }
  }

  /// Execute operation with retry and circuit breaker
  Future<T> _executeWithResilience<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      return await _circuitBreaker.execute(() async {
        var attempts = 0;
        while (true) {
          try {
            attempts++;
            return await action();
          } catch (error) {
            if (!_retryConfig.shouldRetry(error) || attempts >= _retryConfig.maxAttempts) {
              rethrow;
            }
            _eventController.add(RetryAttempt(operation, attempts, _retryConfig.getDelayForAttempt(attempts), error));
            await Future.delayed(_retryConfig.getDelayForAttempt(attempts));
          }
        }
      });
    } on CircuitBreakerException catch (e) {
      _eventController.add(OperationFailure(
        operation,
        'Service temporarily unavailable: ${e.message}',
      ));
      rethrow;
    } catch (e) {
      _eventController.add(OperationFailure(operation, e.toString()));
      rethrow;
    }
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  Future<void> initialize() async {
    await _dataSource.initialize();
  }

  @override
  void dispose() {
    _dataSourceSubscription?.cancel();
    _circuitBreaker.dispose();
    _eventController.close();
    _dataSource.dispose();
  }

  @override
  Stream<Task> create(Task task) async* {
    try {
      await for (final createdTask in Stream.fromFuture(_executeWithResilience(
        'create_task',
        () async {
          await for (final task in _dataSource.create(task)) {
            return task;
          }
          throw Exception('No task received from data source');
        },
      ))) {
        yield createdTask;
      }
    } catch (e) {
      eprint('Failed to create task: $e', '❌');
      rethrow;
    }
  }

  @override
  Stream<Task> update(Task task) async* {
    try {
      await for (final updatedTask in Stream.fromFuture(_executeWithResilience(
        'update_task',
        () async {
          await for (final task in _dataSource.update(task)) {
            return task;
          }
          throw Exception('No task received from data source');
        },
      ))) {
        yield updatedTask;
      }
    } catch (e) {
      eprint('Failed to update task: $e', '❌');
      rethrow;
    }
  }

  @override
  Stream<void> delete(String id) {
    try {
      return _dataSource.delete(id);
    } catch (e) {
      eprint('Failed to delete task: $e', '❌');
      rethrow;
    }
  }

  @override
  Stream<List<Task>> list({Map<String, dynamic>? filters}) async* {
    try {
      await for (final tasks in Stream.fromFuture(_executeWithResilience(
        'list_tasks',
        () async {
          await for (final tasks in _dataSource.list(filters: filters)) {
            return tasks;
          }
          throw Exception('No tasks received from data source');
        },
      ))) {
        yield tasks;
      }
    } catch (e) {
      eprint('Failed to list tasks: $e', '❌');
      rethrow;
    }
  }

  @override
  Stream<Task> read(String id) async* {
    try {
      await for (final task in Stream.fromFuture(_executeWithResilience(
        'read_task',
        () async {
          await for (final task in _dataSource.read(id)) {
            return task;
          }
          throw Exception('No task received from data source');
        },
      ))) {
        yield task;
      }
    } catch (e) {
      eprint('Failed to read task: $e', '❌');
      rethrow;
    }
  }

  @override
  Future<List<Task>> getByStatus(TaskStatus status) async {
    try {
      return await _executeWithResilience(
        'get_tasks_by_status',
        () => _dataSource.getByStatus(status),
      );
    } catch (e) {
      eprint('Failed to get tasks by status: $e', '❌');
      rethrow;
    }
  }

  @override
  Future<List<Task>> getByPriority(TaskPriority priority) async {
    try {
      return await _executeWithResilience(
        'get_tasks_by_priority',
        () => _dataSource.getByPriority(priority),
      );
    } catch (e) {
      eprint('Failed to get tasks by priority: $e', '❌');
      rethrow;
    }
  }

  @override
  Future<List<Task>> getSubtasks(String taskId) async {
    try {
      return await _executeWithResilience(
        'get_subtasks',
        () => _dataSource.getSubtasks(taskId),
      );
    } catch (e) {
      eprint('Failed to get subtasks: $e', '❌');
      rethrow;
    }
  }

  @override
  Future<Task> updateStatus(String taskId, TaskStatus status) async {
    try {
      return await _executeWithResilience(
        'update_task_status',
        () => _dataSource.updateStatus(taskId, status),
      );
    } catch (e) {
      eprint('Failed to update task status: $e', '❌');
      rethrow;
    }
  }
} 