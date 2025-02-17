import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/core/retry_config.dart';
import 'package:ever/domain/core/retry_events.dart';
import 'package:ever/domain/core/circuit_breaker.dart';
import 'package:ever/domain/core/service_events.dart';
import 'package:ever/domain/core/user_events.dart';
import 'package:ever/implementations/datasources/user_ds_impl.dart';
import 'package:ever/implementations/repositories/user_repository_impl.dart';
import 'package:ever/implementations/models/auth_credentials.dart';

import 'auth_flow_test.mocks.dart';

// Import domain events from core
export 'package:ever/domain/core/events.dart';
export 'package:ever/domain/core/retry_events.dart';
export 'package:ever/domain/core/service_events.dart';
export 'package:ever/domain/core/user_events.dart';

class MockIsarCollection extends Mock implements IsarCollection<AuthCredentials> {
  AuthCredentials? _storedCredentials;

  @override
  Future<int> put(AuthCredentials object) async {
    _storedCredentials = object;
    return 1;
  }
  
  @override
  Future<AuthCredentials?> get(int id) async => _storedCredentials;

  @override
  Future<void> clear() async {
    _storedCredentials = null;
  }
}

class MockIsar extends Mock implements Isar {
  final _authCredentialsCollection = MockIsarCollection();

  @override
  IsarCollection<AuthCredentials> collection<AuthCredentials>() {
    return _authCredentialsCollection as IsarCollection<AuthCredentials>;
  }

  @override
  Future<T> writeTxn<T>(Future<T> Function() callback, {bool silent = false}) async {
    return await callback();
  }

  @override
  Future<bool> close({bool deleteFromDisk = false}) async {
    return true;
  }
}

@GenerateMocks([http.Client])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Integration Tests', () {
    late MockClient client;
    late MockIsar isar;
    late UserDataSourceImpl dataSource;
    late UserRepositoryImpl repository;
    late List<DomainEvent> events;

    // Test configurations with reasonable timeouts
    final testRetryConfig = RetryConfig(
      maxAttempts: 3,
      initialDelay: const Duration(milliseconds: 10),
      maxDelay: const Duration(milliseconds: 10),
      backoffFactor: 1.0,
    );

    // Circuit breaker config for retry-focused tests (high threshold)
    final retryFocusedCircuitConfig = CircuitBreakerConfig(
      failureThreshold: 999, // High threshold to prevent circuit from opening
      resetTimeout: const Duration(milliseconds: 100),
      halfOpenMaxAttempts: 1,
    );

    // Circuit breaker config for circuit breaker behavior tests
    final circuitFocusedConfig = CircuitBreakerConfig(
      failureThreshold: 1, // One failure before opening
      resetTimeout: const Duration(milliseconds: 100),
      halfOpenMaxAttempts: 1,
    );

    setUp(() async {
      client = MockClient();
      isar = MockIsar();
      events = [];

      // Create data source with test configs
      dataSource = UserDataSourceImpl(
        isar: isar,
        client: client,
        retryConfig: testRetryConfig,
        circuitBreakerConfig: retryFocusedCircuitConfig, // Default to retry-focused
      );

      // Create repository
      repository = UserRepositoryImpl(dataSource);

      // Setup event collection
      repository.events.listen(events.add);

      // Reset any stored credentials
      await isar.writeTxn(() async {
        await isar.collection<AuthCredentials>().clear();
        // Set up initial user secret
        await isar.collection<AuthCredentials>().put(
          AuthCredentials()
            ..id = 1
            ..userSecret = 'secret123'
        );
      });

      // Reset circuit breaker state
      dataSource.circuitBreaker.reset();
      
      // Clear events
      events.clear();

      // Add a small delay to ensure clean state
      await Future.delayed(const Duration(milliseconds: 50));
    });

    Future<void> waitForEvents(int count, {Duration timeout = const Duration(seconds: 5)}) async {
      if (events.length >= count) return;
      
      final completer = Completer<void>();
      late StreamSubscription subscription;
      
      subscription = repository.events.listen(
        (event) {
          events.add(event);
          if (events.length >= count && !completer.isCompleted) {
            completer.complete();
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      try {
        await completer.future.timeout(timeout);
      } finally {
        await subscription.cancel();
      }
    }

    test('successful registration with intermittent network failures', () async {
      // Create fresh instances with retry-focused config
      dataSource = UserDataSourceImpl(
        isar: isar,
        client: client,
        retryConfig: testRetryConfig,
        circuitBreakerConfig: retryFocusedCircuitConfig,
      );
      repository = UserRepositoryImpl(dataSource);
      events = [];
      repository.events.listen(events.add);
      
      // Setup mock responses
      var attempts = 0;
      when(client.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async {
          attempts++;
          if (attempts < 3) {
            await Future.delayed(const Duration(milliseconds: 10));
            throw http.ClientException('Network error');
          }
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'test123',
                'username': 'testuser',
                'user_secret': 'secret123',
                'created_at': DateTime.now().toIso8601String(),
              }
            }),
            201,
          );
        });

      // Execute registration and wait for events
      final user = await repository.register('testuser').first;
      await waitForEvents(5); // Wait for all 5 expected events

      // Verify events
      expect(events, containsAllInOrder([
        isA<OperationInProgress>(),
        isA<RetryAttempt>(),
        isA<RetryAttempt>(),
        isA<RetrySuccess>(),
        isA<UserRegistered>(),
      ]));

      // Verify user data
      expect(user.username, 'testuser');
      expect(user.userSecret, 'secret123');
    });

    test('circuit breaker opens after consecutive failures', () async {
      // Use circuit-focused config for this test
      dataSource = UserDataSourceImpl(
        isar: isar,
        client: client,
        retryConfig: testRetryConfig,
        circuitBreakerConfig: circuitFocusedConfig,
      );
      repository = UserRepositoryImpl(dataSource);
      events = [];

      // Setup event listeners first
      final eventCompleter = Completer<void>();
      int expectedEvents = 6; // We expect 6 events in total
      
      repository.events.listen((event) {
        events.add(event);
        if (events.length >= expectedEvents && !eventCompleter.isCompleted) {
          eventCompleter.complete();
        }
      });

      dataSource.circuitBreaker.events.listen((event) {
        // Convert circuit breaker events to domain events
        switch (event.type) {
          case 'transition_to_open':
            events.add(ServiceDegraded(event.timestamp));
            break;
          case 'operation_rejected':
            events.add(OperationRejected('Circuit is open'));
            break;
        }
        if (events.length >= expectedEvents && !eventCompleter.isCompleted) {
          eventCompleter.complete();
        }
      });

      // Setup mock to always fail
      when(client.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 10));
          throw http.ClientException('Server error');
        });

      // First attempt - should fail and open circuit
      try {
        await repository.register('testuser').first;
        fail('Should throw exception');
      } catch (e) {
        expect(e, isA<CircuitBreakerException>());
        expect(e.toString(), contains('Circuit is open'));
      }

      // Wait for all events
      await eventCompleter.future.timeout(const Duration(seconds: 1));

      // Verify events
      expect(events, containsAllInOrder([
        isA<OperationInProgress>(),
        isA<RetryAttempt>(),
        isA<ServiceDegraded>(),
        isA<OperationRejected>(),
        isA<RetryExhausted>(),
        isA<TokenAcquisitionFailed>(),
      ]));

      // Reset events for next attempt
      events.clear();

      // Second attempt - should be rejected by open circuit immediately
      try {
        await repository.register('testuser').first;
        fail('Should throw exception');
      } catch (e) {
        expect(e, isA<CircuitBreakerException>());
        expect(e.toString(), contains('Circuit is open'));
      }

      // Wait for events to be processed
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify events
      expect(events, containsAllInOrder([
        isA<OperationInProgress>(),
        isA<OperationRejected>(),
        isA<TokenAcquisitionFailed>(),
      ]));
    });

    test('circuit breaker recovery after reset timeout', () async {
      // Use circuit-focused config for this test
      dataSource = UserDataSourceImpl(
        isar: isar,
        client: client,
        retryConfig: testRetryConfig,
        circuitBreakerConfig: circuitFocusedConfig,
      );
      repository = UserRepositoryImpl(dataSource);
      events = [];
      repository.events.listen(events.add);

      // Setup mock to fail initially then succeed
      var attempts = 0;
      when(client.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async {
          attempts++;
          if (attempts <= 1) {
            await Future.delayed(const Duration(milliseconds: 10));
            throw http.ClientException('Server error');
          }
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'test123',
                'username': 'testuser',
                'user_secret': 'secret123',
                'created_at': DateTime.now().toIso8601String(),
              }
            }),
            201,
          );
        });

      // First attempt - should fail and open circuit
      try {
        await repository.register('testuser').first;
        fail('Should throw exception');
      } catch (e) {
        expect(e, isA<CircuitBreakerException>());
        expect(e.toString(), contains('Circuit is open'));
      }
      await waitForEvents(2); // Wait for OperationInProgress and ServiceDegraded

      // Wait for reset timeout
      await Future.delayed(const Duration(milliseconds: 150));

      // Reset events for final attempt
      events.clear();

      // Second attempt - should succeed in half-open state
      final user = await repository.register('testuser').first;
      await waitForEvents(3); // Wait for all expected events

      // Verify events
      expect(events, containsAllInOrder([
        isA<OperationInProgress>(),
        isA<ServiceRestored>(),
        isA<UserRegistered>(),
      ]));

      // Verify user data
      expect(user.username, 'testuser');
      expect(user.userSecret, 'secret123');
    });

    test('token refresh with retry and circuit breaker', () async {
      // Create fresh instances with retry-focused config
      dataSource = UserDataSourceImpl(
        isar: isar,
        client: client,
        retryConfig: testRetryConfig,
        circuitBreakerConfig: retryFocusedCircuitConfig,
      );
      repository = UserRepositoryImpl(dataSource);
      events = [];
      repository.events.listen(events.add);

      // Setup mock responses
      var attempts = 0;
      when(client.post(any, headers: anyNamed('headers'), body: anyNamed('body')))
        .thenAnswer((_) async {
          attempts++;
          if (attempts < 3) {
            await Future.delayed(const Duration(milliseconds: 10));
            throw http.ClientException('Network error');
          }
          return http.Response(
            jsonEncode({
              'data': {
                'access_token': 'token123',
              }
            }),
            200,
          );
        });

      // Set up user secret for token refresh
      await isar.writeTxn(() async {
        await isar.collection<AuthCredentials>().put(
          AuthCredentials()
            ..id = 1
            ..userSecret = 'secret123'
            ..accessToken = 'old_token'
            ..tokenExpiresAt = DateTime.now().add(const Duration(hours: 1))
        );
      });

      // Initialize repository to load user secret
      await repository.initialize();

      // Execute token refresh
      final token = await repository.refreshToken().first;

      // Verify events
      expect(events, containsAllInOrder([
        isA<OperationInProgress>(),
        isA<RetryAttempt>(),
        isA<RetryAttempt>(),
        isA<RetrySuccess>(),
        isA<TokenObtained>(),
      ]));

      // Verify token
      expect(token, 'token123');
    });

    tearDown(() async {
      // Wait for any pending events
      await Future.delayed(const Duration(milliseconds: 50));
      repository.dispose();
      dataSource.dispose();
    });
  });
}
