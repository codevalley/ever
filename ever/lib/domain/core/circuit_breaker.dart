import 'dart:async';
import 'package:meta/meta.dart';

/// Circuit breaker states.
enum CircuitState { closed, open, halfOpen }

/// Configuration for circuit breaker pattern.
class CircuitBreakerConfig {
  /// Number of failures before opening the circuit.
  final int failureThreshold;

  /// How long to wait before attempting recovery.
  final Duration resetTimeout;

  /// Maximum number of trial calls allowed in half‑open state.
  final int halfOpenMaxAttempts;

  /// Default configuration with reasonable values.
  static const CircuitBreakerConfig defaultConfig = CircuitBreakerConfig(
    failureThreshold: 5,
    resetTimeout: Duration(seconds: 30),
    halfOpenMaxAttempts: 3,
  );

  const CircuitBreakerConfig({
    required this.failureThreshold,
    required this.resetTimeout,
    required this.halfOpenMaxAttempts,
  });
}

/// Implementation of the circuit breaker pattern.
class CircuitBreaker {
  final CircuitBreakerConfig _config;
  final _eventController = StreamController<CircuitBreakerEvent>.broadcast();

  CircuitState _state = CircuitState.closed;
  int _failures = 0;
  int _halfOpenAttempts = 0;
  DateTime? _lastFailure;
  Timer? _resetTimer;

  CircuitBreaker([CircuitBreakerConfig? config])
      : _config = config ?? CircuitBreakerConfig.defaultConfig;

  /// Current state of the circuit.
  CircuitState get state => _state;

  /// Stream of circuit breaker events.
  Stream<CircuitBreakerEvent> get events => _eventController.stream;

  /// Check if enough time has passed to attempt reset
  @visibleForTesting
  bool get shouldAttemptReset {
    if (_lastFailure == null) return false;
    final elapsed = DateTime.now().difference(_lastFailure!);
    return elapsed >= _config.resetTimeout;
  }

  /// Execute an operation through the circuit breaker.
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_state == CircuitState.open) {
      if (shouldAttemptReset) {
        _transitionToHalfOpen();
      } else {
        _eventController.add(CircuitBreakerEvent.operationRejected());
        throw CircuitBreakerException('Circuit is open');
      }
    }

    if (_state == CircuitState.halfOpen) {
      if (_halfOpenAttempts >= _config.halfOpenMaxAttempts) {
        _eventController.add(CircuitBreakerEvent.operationRejected());
        throw CircuitBreakerException('Maximum half-open attempts reached');
      }
      _halfOpenAttempts++;
    }

    try {
      final result = await operation();
      if (_state == CircuitState.halfOpen) {
        // Only transition to closed if we've used all allowed trial attempts
        if (_halfOpenAttempts >= _config.halfOpenMaxAttempts) {
          _transitionToClosed();
        }
      } else if (_state == CircuitState.closed) {
        _failures = 0;
      }
      return result;
    } catch (error) {
      if (_state == CircuitState.halfOpen) {
        // Any failure in half-open immediately transitions back to open
        _transitionToOpen();
      } else if (_state == CircuitState.closed) {
        _failures++;
        if (_failures >= _config.failureThreshold) {
          _transitionToOpen();
        }
      }
      rethrow;
    }
  }

  /// Transition to closed state.
  void _transitionToClosed() {
    _state = CircuitState.closed;
    _failures = 0;
    _halfOpenAttempts = 0;
    _lastFailure = null;
    _resetTimer?.cancel();
    _eventController.add(CircuitBreakerEvent.transitionToClosed());
  }

  /// Transition to open state.
  void _transitionToOpen() {
    _state = CircuitState.open;
    _lastFailure = DateTime.now();
    _halfOpenAttempts = 0;
    _resetTimer?.cancel();
    // Schedule automatic transition to half-open after reset timeout
    _resetTimer = Timer(_config.resetTimeout, _transitionToHalfOpen);
    _eventController.add(CircuitBreakerEvent.transitionToOpen());
  }

  /// Transition to half‑open state.
  void _transitionToHalfOpen() {
    _state = CircuitState.halfOpen;
    _halfOpenAttempts = 0;
    _eventController.add(CircuitBreakerEvent.transitionToHalfOpen());
  }

  /// Reset the circuit breaker to its initial state.
  void reset() {
    _state = CircuitState.closed;
    _failures = 0;
    _halfOpenAttempts = 0;
    _lastFailure = null;
    _resetTimer?.cancel();
    _eventController.add(CircuitBreakerEvent.transitionToClosed());
  }

  /// Dispose of resources.
  void dispose() {
    _resetTimer?.cancel();
    _eventController.close();
  }

  // The following method is made public for testing purposes only.
  @visibleForTesting
  void forceTransitionToHalfOpen() {
    _transitionToHalfOpen();
  }
}

/// Events emitted by the circuit breaker.
class CircuitBreakerEvent {
  final String type;
  final String? message;
  final DateTime timestamp;

  CircuitBreakerEvent._(this.type, [this.message]) : timestamp = DateTime.now();

  factory CircuitBreakerEvent.transitionToOpen() =>
      CircuitBreakerEvent._('transition_to_open');

  factory CircuitBreakerEvent.transitionToHalfOpen() =>
      CircuitBreakerEvent._('transition_to_half_open');

  factory CircuitBreakerEvent.transitionToClosed() =>
      CircuitBreakerEvent._('transition_to_closed');

  factory CircuitBreakerEvent.operationRejected() =>
      CircuitBreakerEvent._('operation_rejected', 'Operation rejected due to circuit breaker state');
}

/// Exception thrown when circuit breaker prevents an operation.
class CircuitBreakerException implements Exception {
  final String message;
  CircuitBreakerException(this.message);

  @override
  String toString() => 'CircuitBreakerException: $message';
}
