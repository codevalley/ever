/// Base class for all domain events
abstract class DomainEvent {
  const DomainEvent();
}

/// Event emitted when an operation starts
class OperationInProgress extends DomainEvent {
  final String operation;

  const OperationInProgress(this.operation);
}

/// Event emitted when an operation succeeds
class OperationSuccess<T> extends DomainEvent {
  final String operation;
  final T? data;

  const OperationSuccess(this.operation, [this.data]);
}

/// Event emitted when an operation fails
class OperationFailure extends DomainEvent {
  final String operation;
  final String error;

  const OperationFailure(this.operation, this.error);
}
