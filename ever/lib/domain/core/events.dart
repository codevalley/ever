/// Base class for all domain events
abstract class DomainEvent {}

/// Event indicating an operation is in progress
class OperationInProgress extends DomainEvent {
  final String operation;
  OperationInProgress(this.operation);
}

/// Event indicating an operation succeeded
class OperationSuccess<T> extends DomainEvent {
  final String operation;
  final T data;
  OperationSuccess(this.operation, this.data);
}

/// Event indicating an operation failed
class OperationFailure extends DomainEvent {
  final String operation;
  final String message;
  final dynamic error;
  OperationFailure(this.operation, this.message, [this.error]);
}
