import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ever/domain/core/circuit_breaker.dart';

void main() {
  group('CircuitBreaker', () {
    late CircuitBreaker circuitBreaker;
    
    final testConfig = CircuitBreakerConfig(
      failureThreshold: 3,
      resetTimeout: Duration(milliseconds: 100),
      halfOpenMaxAttempts: 2,
    );

    setUp(() {
      circuitBreaker = CircuitBreaker(testConfig);
    });

    test('should start in closed state', () {
      expect(circuitBreaker.state, equals(CircuitState.closed));
    });

    test('should transition to open after failure threshold', () async {
      // Simulate failures.
      for (var i = 0; i < testConfig.failureThreshold - 1; i++) {
        try {
          await circuitBreaker.execute(() => Future.error('error'));
          fail('Should throw error');
        } catch (e) {
          // Expected.
        }
      }
      // Last failure should trigger transition to open.
      try {
        await circuitBreaker.execute(() => Future.error('error'));
        fail('Should throw error');
      } catch (e) {
        // Expected.
      }
      expect(circuitBreaker.state, equals(CircuitState.open));
    });

    test('should reject calls when open', () async {
      // Force circuit to open.
      for (var i = 0; i < testConfig.failureThreshold; i++) {
        try {
          await circuitBreaker.execute(() => Future.error('error'));
        } catch (_) {}
      }
      expect(circuitBreaker.state, equals(CircuitState.open));

      // Attempt call when open.
      try {
        await circuitBreaker.execute(() => Future.value('success'));
        fail('Should reject call');
      } catch (e) {
        expect(e, isA<CircuitBreakerException>());
        expect(e.toString(), contains('Circuit is open'));
      }
    });

    test('should transition to half-open after reset timeout', () async {
      // Force circuit to open.
      for (var i = 0; i < testConfig.failureThreshold; i++) {
        try {
          await circuitBreaker.execute(() => Future.error('error'));
        } catch (_) {}
      }
      expect(circuitBreaker.state, equals(CircuitState.open));

      // Wait for reset timeout.
      await Future.delayed(testConfig.resetTimeout * 2);

      // First call after timeout transitions to half-open.
      try {
        await circuitBreaker.execute(() => Future.value('success'));
      } catch (_) {}
      // With halfOpenMaxAttempts = 2, the first successful trial leaves state in half-open.
      expect(circuitBreaker.state, equals(CircuitState.halfOpen));
    });

    test('should transition to closed after successful half-open calls', () async {
      // Force circuit to open.
      for (var i = 0; i < testConfig.failureThreshold; i++) {
        try {
          await circuitBreaker.execute(() => Future.error('error'));
        } catch (_) {}
      }
      await Future.delayed(testConfig.resetTimeout * 2);

      // First successful trial call.
      final result1 = await circuitBreaker.execute(() => Future.value('success'));
      expect(result1, equals('success'));
      // Since halfOpenMaxAttempts is 2, state should still be half-open.
      expect(circuitBreaker.state, equals(CircuitState.halfOpen));

      // Second successful trial call triggers transition to closed.
      final result2 = await circuitBreaker.execute(() => Future.value('success'));
      expect(result2, equals('success'));
      expect(circuitBreaker.state, equals(CircuitState.closed));
    });

    test('should transition back to open on failure in half-open state', () async {
      // Force circuit to open.
      for (var i = 0; i < testConfig.failureThreshold; i++) {
        try {
          await circuitBreaker.execute(() => Future.error('error'));
        } catch (_) {}
      }
      await Future.delayed(testConfig.resetTimeout * 2);

      // A failure in half-open immediately transitions to open.
      try {
        await circuitBreaker.execute(() => Future.error('error'));
        fail('Should throw error');
      } catch (_) {}
      expect(circuitBreaker.state, equals(CircuitState.open));
    });

    test('should limit attempts in half-open state', () async {
      // Force circuit to open.
      for (var i = 0; i < testConfig.failureThreshold; i++) {
        try {
          await circuitBreaker.execute(() => Future.error('error'));
        } catch (_) {}
      }
      expect(circuitBreaker.state, equals(CircuitState.open));
      await Future.delayed(testConfig.resetTimeout * 2);

      // Start one pending trial call to move into half-open.
      final completer = Completer<String>();
      final pending = circuitBreaker.execute(() => completer.future);

      // Without waiting for the first trial to complete, a second call is allowed
      // (since halfOpenMaxAttempts = 2). Now the number of trial calls equals the limit.
      final trial2 = circuitBreaker.execute(() => Future.value('success'));

      // A third call should be rejected.
      try {
        await circuitBreaker.execute(() => Future.value('ignored'));
        fail('Should reject call');
      } catch (e) {
        expect(e, isA<CircuitBreakerException>());
        expect(e.toString(), contains('Maximum half-open attempts reached'));
      }

      // Complete the pending trial calls.
      completer.complete('done');
      await pending;
      await trial2;
    });

    tearDown(() {
      circuitBreaker.dispose();
    });
  });
}
