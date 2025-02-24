/// Base class for all domain exceptions
abstract class DomainException implements Exception {
  final String message;
  
  const DomainException(this.message);
  
  @override
  String toString() => '$runtimeType: $message';
}

/// Base exception class for all task-related exceptions
class TaskException extends DomainException {
  const TaskException(super.message);
}

/// Exception thrown when a task is not found
class TaskNotFoundException extends TaskException {
  final String taskId;
  
  TaskNotFoundException(this.taskId) : super('Task not found: $taskId');
  
  @override
  String toString() => 'TaskNotFoundException: $message';
}

/// Exception thrown when task validation fails
class TaskValidationException extends TaskException {
  TaskValidationException(super.message);
}

/// Exception thrown when a network operation fails
class TaskNetworkException extends TaskException {
  TaskNetworkException([String? message]) 
    : super(message ?? 'Network operation failed');
}

/// Exception thrown when concurrent operations are attempted
class TaskConcurrencyException extends TaskException {
  TaskConcurrencyException(super.message);
}

/// Exception thrown when a task operation times out
class TaskTimeoutException extends TaskException {
  TaskTimeoutException([String? message]) 
    : super(message ?? 'Operation timed out');
}

/// Exception thrown when retry attempts are exhausted
class TaskRetryExhaustedException extends TaskException {
  final int attempts;
  final String operation;
  
  TaskRetryExhaustedException({
    required this.attempts,
    required this.operation,
  }) : super('Retry exhausted after $attempts attempts for $operation');
}

/// Thrown when a note operation fails due to validation errors
class NoteValidationException extends DomainException {
  NoteValidationException(super.message);
}

/// Thrown when a note is not found
class NoteNotFoundException extends DomainException {
  NoteNotFoundException(super.message);
}

/// Thrown when a note operation fails due to network errors
class NoteNetworkException extends DomainException {
  NoteNetworkException(super.message);
}

/// Thrown when attempting concurrent operations on a note
class NoteConcurrencyException extends DomainException {
  NoteConcurrencyException(super.message);
} 