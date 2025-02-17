import 'dart:async';

/// Configuration for retry mechanism with exponential backoff
class RetryConfig {
  /// Maximum number of retry attempts
  final int maxAttempts;

  /// Initial delay before first retry
  final Duration initialDelay;

  /// Maximum delay between retries
  final Duration maxDelay;

  /// Multiplier for each subsequent retry
  final double backoffFactor;

  /// Default configuration with reasonable values
  static const RetryConfig defaultConfig = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 10),
    backoffFactor: 2.0,
  );

  const RetryConfig({
    required this.maxAttempts,
    required this.initialDelay,
    required this.maxDelay,
    required this.backoffFactor,
  });

  /// Calculate delay for a specific attempt number
  Duration getDelayForAttempt(int attempt) {
    if (attempt <= 0) return Duration.zero;
    
    final exponentialDelay = initialDelay * (backoffFactor * (attempt - 1));
    return exponentialDelay > maxDelay ? maxDelay : exponentialDelay;
  }

  /// Check if an error should trigger a retry
  bool shouldRetry(Object error) {
    // Retry on network errors and server errors (5xx)
    return error is TimeoutException ||
           error.toString().contains('NetworkError') ||
           error.toString().contains('SocketException') ||
           error.toString().contains('500') ||
           error.toString().contains('502') ||
           error.toString().contains('503') ||
           error.toString().contains('504');
  }
}

/// Extension to add retry capability to Future operations
extension RetryableOperation<T> on Future<T> Function() {
  /// Execute the operation with retry logic
  Future<T> withRetry(RetryConfig config) async {
    int attempts = 0;
    
    while (true) {
      try {
        attempts++;
        return await this();
      } catch (error) {
        if (!config.shouldRetry(error) || attempts >= config.maxAttempts) {
          rethrow;
        }
        
        final delay = config.getDelayForAttempt(attempts);
        await Future.delayed(delay);
      }
    }
  }
} 