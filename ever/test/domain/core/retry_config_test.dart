import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ever/domain/core/retry_config.dart';

void main() {
  group('RetryConfig', () {
    late RetryConfig config;

    setUp(() {
      config = const RetryConfig(
        maxAttempts: 3,
        initialDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 5),
        backoffFactor: 2.0,
      );
    });

    test('should calculate correct delay for each attempt', () {
      expect(config.getDelayForAttempt(0), Duration.zero);
      expect(config.getDelayForAttempt(1), const Duration(seconds: 1));
      expect(config.getDelayForAttempt(2), const Duration(seconds: 2));
      expect(config.getDelayForAttempt(3), const Duration(seconds: 4));
      // Should cap at maxDelay
      expect(config.getDelayForAttempt(4), const Duration(seconds: 5));
    });

    test('should correctly identify retryable errors', () {
      expect(config.shouldRetry(TimeoutException('Timeout')), true);
      expect(config.shouldRetry(Exception('NetworkError occurred')), true);
      expect(config.shouldRetry(Exception('SocketException: Failed to connect')), true);
      expect(config.shouldRetry(Exception('500 Internal Server Error')), true);
      expect(config.shouldRetry(Exception('502 Bad Gateway')), true);
      expect(config.shouldRetry(Exception('503 Service Unavailable')), true);
      expect(config.shouldRetry(Exception('504 Gateway Timeout')), true);
      
      // Non-retryable errors
      expect(config.shouldRetry(Exception('400 Bad Request')), false);
      expect(config.shouldRetry(Exception('401 Unauthorized')), false);
      expect(config.shouldRetry(Exception('404 Not Found')), false);
      expect(config.shouldRetry(Exception('ValidationError')), false);
    });
  });

  group('RetryableOperation', () {
    late RetryConfig config;
    late List<DateTime> attemptTimes;

    setUp(() {
      config = const RetryConfig(
        maxAttempts: 3,
        initialDelay: Duration(milliseconds: 50),
        maxDelay: Duration(milliseconds: 200),
        backoffFactor: 2.0,
      );
      attemptTimes = [];
    });

    Future<String> successAfterAttempts(int failureCount) async {
      attemptTimes.add(DateTime.now());
      if (attemptTimes.length <= failureCount) {
        throw TimeoutException('Simulated timeout');
      }
      return 'Success';
    }

    test('should succeed without retry on first attempt', () async {
      operation() => Future.value('Success');
      final result = await operation.withRetry(config);
      expect(result, 'Success');
    });

    test('should retry and succeed within max attempts', () async {
      operation() => successAfterAttempts(2);
      final result = await operation.withRetry(config);
      expect(result, 'Success');
      expect(attemptTimes.length, 3);

      // Verify delays between attempts
      final firstDelay = attemptTimes[1].difference(attemptTimes[0]).inMilliseconds;
      final secondDelay = attemptTimes[2].difference(attemptTimes[1]).inMilliseconds;
      
      expect(firstDelay, greaterThanOrEqualTo(45)); // Allow for small timing variations
      expect(secondDelay, greaterThanOrEqualTo(90)); // Allow for small timing variations
    });

    test('should throw after max attempts', () async {
      operation() => successAfterAttempts(3);
      expect(
        () => operation.withRetry(config),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('should not retry on non-retryable errors', () async {
      operation() => Future.error(Exception('400 Bad Request'));
      expect(
        () => operation.withRetry(config),
        throwsA(isA<Exception>()),
      );
      expect(attemptTimes.isEmpty, true);
    });
  });
} 