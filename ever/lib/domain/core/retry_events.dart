import 'events.dart';

/// Event emitted when a retry attempt is about to start
class RetryAttempt extends DomainEvent {
  /// The operation being retried
  final String operation;
  
  /// The attempt number (1-based)
  final int attempt;
  
  /// The delay before this attempt
  final Duration delay;
  
  /// The error that triggered this retry
  final Object error;

  const RetryAttempt(
    this.operation,
    this.attempt,
    this.delay,
    this.error,
  );
}

/// Event emitted when a retry succeeds
class RetrySuccess extends DomainEvent {
  /// The operation that succeeded
  final String operation;
  
  /// The number of attempts it took
  final int attempts;

  const RetrySuccess(this.operation, this.attempts);
}

/// Event emitted when all retries are exhausted
class RetryExhausted extends DomainEvent {
  /// The operation that failed
  final String operation;
  
  /// The final error
  final Object error;
  
  /// The number of attempts made
  final int attempts;

  const RetryExhausted(this.operation, this.error, this.attempts);
} 