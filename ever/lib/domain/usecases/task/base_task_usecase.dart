import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/core/exceptions.dart';
import 'package:ever/domain/usecases/base_usecase.dart';

/// Base class for all task-related use cases
/// [P] is the parameter type for the use case
abstract class BaseTaskUseCase<P> extends BaseUseCase<P> {
  final _eventController = StreamController<DomainEvent>.broadcast();
  bool _isInProgress = false;
  
  /// Name of the operation for event emission
  String get operationName;

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  /// Event controller for subclasses to emit events
  StreamController<DomainEvent> get eventController => _eventController;

  /// Whether an operation is currently in progress
  bool get isOperationInProgress => _isInProgress;

  /// Execute operation with proper error handling and event emission
  Future<T> executeOperation<T>(Future<T> Function() operation) async {
    _checkConcurrency();
    
    try {
      _eventController.add(OperationInProgress(operationName));
      final result = await operation();
      _eventController.add(OperationSuccess(operationName));
      return result;
    } on DomainException {
      rethrow;
    } catch (e) {
      final error = e.toString();
      _eventController.add(OperationFailure(operationName, error));
      throw TaskNetworkException(error);
    } finally {
      _isInProgress = false;
    }
  }

  /// Execute void operation with proper error handling and event emission
  Future<bool> executeVoidOperation(Future<void> Function() operation) async {
    _checkConcurrency();
    
    try {
      _eventController.add(OperationInProgress(operationName));
      await operation();
      _eventController.add(OperationSuccess(operationName));
      return true;
    } on DomainException {
      rethrow;
    } catch (e) {
      final error = e.toString();
      _eventController.add(OperationFailure(operationName, error));
      throw TaskNetworkException(error);
    } finally {
      _isInProgress = false;
    }
  }

  /// Execute stream operation with proper error handling and event emission
  Stream<T> executeStreamOperation<T>(
    Stream<T> Function() operation,
  ) async* {
    _checkConcurrency();
    
    try {
      _eventController.add(OperationInProgress(operationName));
      await for (final result in operation()) {
        yield result;
      }
      _eventController.add(OperationSuccess(operationName));
    } on DomainException {
      rethrow;
    } catch (e) {
      final error = e.toString();
      _eventController.add(OperationFailure(operationName, error));
      throw TaskNetworkException(error);
    } finally {
      _isInProgress = false;
    }
  }

  /// Validate that a string is not empty
  void validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      _eventController.add(OperationInProgress(operationName));
      _eventController.add(OperationFailure(operationName, '$fieldName cannot be empty'));
      throw TaskValidationException('$fieldName cannot be empty');
    }
  }

  /// Validate task ID
  void validateTaskId(String? taskId) {
    validateNotEmpty(taskId, 'Task ID');
  }

  /// Validate task content
  void validateTaskContent(String? content) {
    if (content != null && content.isEmpty) {
      _eventController.add(OperationInProgress(operationName));
      _eventController.add(OperationFailure(operationName, 'Content cannot be empty if provided'));
      throw TaskValidationException('Content cannot be empty if provided');
    }
  }

  /// Validate task status
  void validateTaskStatus(String? status) {
    if (status != null && !['todo', 'in_progress', 'done'].contains(status)) {
      _eventController.add(OperationInProgress(operationName));
      _eventController.add(OperationFailure(operationName, 'Invalid status. Must be one of: todo, in_progress, done'));
      throw TaskValidationException(
        'Invalid status. Must be one of: todo, in_progress, done',
      );
    }
  }

  /// Handle validation error with events
  void handleValidationError(String error) {
    _eventController.add(OperationInProgress(operationName));
    _eventController.add(OperationFailure(operationName, error));
    throw TaskValidationException(error);
  }

  /// Check if an operation is already in progress
  void _checkConcurrency() {
    if (_isInProgress) {
      throw StateError('$operationName already in progress');
    }
    _isInProgress = true;
  }

  /// Clean up resources
  @override
  Future<void> dispose() async {
    if (!_eventController.isClosed) {
      await _eventController.close();
    }
  }
} 