import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:math';

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
    
    // Calculate exponential delay: initialDelay * (backoffFactor ^ (attempt - 1))
    final multiplier = pow(backoffFactor, attempt - 1).toDouble();
    final exponentialDelay = initialDelay * multiplier;
    return exponentialDelay > maxDelay ? maxDelay : exponentialDelay;
  }

  /// Check if an error should trigger a retry
  bool shouldRetry(Object error) {
    if (error is TimeoutException) return true;
    if (error is http.ClientException) return true;
    if (error is SocketException) return true;
    final errorString = error.toString().toLowerCase();
    return errorString.contains('500') ||
           errorString.contains('502') ||
           errorString.contains('503') ||
           errorString.contains('504') ||
           errorString.contains('network error') ||
           errorString.contains('networkerror') ||
           errorString.contains('socketexception') ||
           errorString.contains('failed to connect');
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