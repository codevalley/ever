import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/core/retry_config.dart';
import 'package:ever/domain/core/circuit_breaker.dart';
import 'package:ever/domain/events/user_events.dart';
import 'package:ever/domain/entities/user.dart';
import 'package:ever/implementations/datasources/user_ds_impl.dart';
import 'package:ever/implementations/repositories/user_repository_impl.dart';
import 'package:ever/domain/core/local_cache.dart';

import 'auth_flow_test.mocks.dart';

// Import domain events from core
export 'package:ever/domain/core/events.dart';
export 'package:ever/domain/core/retry_events.dart';
export 'package:ever/domain/core/service_events.dart';
export 'package:ever/domain/events/user_events.dart';

@GenerateMocks([http.Client, LocalCache])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Integration Tests', () {
    late MockClient client;
    late UserDataSourceImpl dataSource;
    late UserRepositoryImpl repository;
    late List<DomainEvent> events;
    late MockLocalCache mockCache;
    late StreamController<CircuitBreakerEvent> circuitBreakerEvents;

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
      events = [];
      mockCache = MockLocalCache();
      circuitBreakerEvents = StreamController<CircuitBreakerEvent>.broadcast();

      // Setup initial cache state
      when(mockCache.initialize()).thenAnswer((_) async {});
      when(mockCache.get<String>('userSecret')).thenAnswer((_) async => null);
      when(mockCache.get<String>('accessToken')).thenAnswer((_) async => null);
      when(mockCache.get<String>('tokenExpiresAt')).thenAnswer((_) async => null);
      when(mockCache.set(any, any)).thenAnswer((_) async {});
      when(mockCache.clear()).thenAnswer((_) async {});

      // Create data source with test configs
      dataSource = UserDataSourceImpl(
        client: client,
        cache: mockCache,
        retryConfig: testRetryConfig,
        circuitBreakerConfig: retryFocusedCircuitConfig,
      );

      // Create repository
      repository = UserRepositoryImpl(dataSource);

      // Setup event collection
      repository.events.listen(events.add);
    });

    tearDown(() {
      dataSource.dispose();
      circuitBreakerEvents.close();
    });

    test('successful registration and login', () async {
      // Arrange
      final username = 'testuser';
      final userSecret = 'secret123';
      final token = 'token123';
      final user = User(
        id: 'user123',
        username: username,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Setup response sequence
      var responseCount = 0;
      when(client.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async {
        responseCount++;
        if (responseCount == 1) {
          // Registration response
          return http.Response(
            json.encode({
              'data': {
                'id': user.id,
                'username': user.username,
                'created_at': user.createdAt.toIso8601String(),
                'updated_at': user.updatedAt?.toIso8601String(),
                'user_secret': userSecret,
              }
            }),
            201,
          );
        } else {
          // Token response
          return http.Response(
            json.encode({
              'data': {
                'access_token': token,
              }
            }),
            200,
          );
        }
      });

      // Mock user info response
      when(client.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
            json.encode({
              'data': {
                'id': user.id,
                'username': user.username,
                'created_at': user.createdAt.toIso8601String(),
                'updated_at': user.updatedAt?.toIso8601String(),
              }
            }),
            200,
          ));

      // Mock cache operations for token
      when(mockCache.get<String>('accessToken')).thenAnswer((_) async => token);
      when(mockCache.get<String>('userSecret')).thenAnswer((_) async => userSecret);

      // Act & Assert - Registration
      final events = <DomainEvent>[];
      final subscription = dataSource.events.listen(events.add);

      final registeredUser = await dataSource.register(username).first;
      expect(registeredUser.username, equals(username));
      verify(mockCache.set('userSecret', userSecret)).called(1);

      // Act & Assert - Login
      final obtainedToken = await dataSource.obtainToken(userSecret).first;
      expect(obtainedToken, equals(token));
      verify(mockCache.set('accessToken', token)).called(1);
      verify(mockCache.set('tokenExpiresAt', any)).called(1);

      // Act & Assert - Get Current User
      final currentUser = await dataSource.getCurrentUser().first;
      expect(currentUser.username, equals(username));

      // Act & Assert - Logout
      await dataSource.signOut().drain<void>();
      verify(mockCache.clear()).called(1);

      // Verify event sequence
      expect(events, containsAllInOrder([
        isA<OperationInProgress>(), // Register start
        isA<UserRegistered>(), // Register success
        isA<OperationInProgress>(), // Token start
        isA<TokenObtained>(), // Token success
        isA<OperationInProgress>(), // Get user start
        isA<CurrentUserRetrieved>(), // Get user success
        isA<OperationInProgress>(), // Logout start
        isA<UserLoggedOut>(), // Logout success
      ]));

      await subscription.cancel();
    });

    test('handles token expiration and refresh', () async {
      // Arrange
      final userSecret = 'secret123';
      final token1 = 'token123';
      final token2 = 'token456';
      final user = User(
        id: 'user123',
        username: 'testuser',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Setup response sequence for token refresh
      var tokenAttempts = 0;
      when(client.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async {
        tokenAttempts++;
        return http.Response(
          json.encode({
            'data': {
              'access_token': tokenAttempts == 1 ? token1 : token2,
            }
          }),
          200,
        );
      });

      // Mock user info responses
      var userAttempts = 0;
      when(client.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) {
        userAttempts++;
        if (userAttempts == 1) {
          // First attempt - token expired
          return Future.value(http.Response(
            json.encode({
              'message': 'Token expired',
            }),
            401,
          ));
        }
        // Second attempt - success with new token
        return Future.value(http.Response(
          json.encode({
            'data': {
              'id': user.id,
              'username': user.username,
              'created_at': user.createdAt.toIso8601String(),
              'updated_at': user.updatedAt?.toIso8601String(),
            }
          }),
          200,
        ));
      });

      // Mock cache operations
      when(mockCache.get<String>('accessToken')).thenAnswer((_) async => token1);
      when(mockCache.get<String>('userSecret')).thenAnswer((_) async => userSecret);

      // Act & Assert
      final events = <DomainEvent>[];
      final subscription = dataSource.events.listen(events.add);

      // First attempt - should trigger refresh
      final currentUser = await dataSource.getCurrentUser().first;
      expect(currentUser.username, equals(user.username));

      // Add a small delay to ensure all events are processed
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify event sequence
      expect(events, containsAllInOrder([
        isA<OperationInProgress>(), // Get user start
        isA<OperationInProgress>(), // Token refresh start
        isA<TokenObtained>(), // Token refresh success
        isA<CurrentUserRetrieved>(), // Get user success
      ]));

      await subscription.cancel();
    });

    test('handles circuit breaker', () async {
      // Create fresh instance with circuit-focused config
      dataSource = UserDataSourceImpl(
        client: client,
        cache: mockCache,
        retryConfig: testRetryConfig,
        circuitBreakerConfig: circuitFocusedConfig,
      );

      // Arrange
      final userSecret = 'secret123';
      final error = 'Service unavailable';

      // Mock token response to always fail
      when(client.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async => http.Response(
            json.encode({
              'message': error,
            }),
            503,
          ));

      // Mock cache operations
      when(mockCache.get<String>('userSecret')).thenAnswer((_) async => userSecret);

      // Act & Assert
      final events = <DomainEvent>[];
      final subscription = dataSource.events.listen(events.add);

      // Make multiple failed attempts
      for (var i = 0; i < 3; i++) {
        try {
          await dataSource.obtainToken(userSecret).first;
          fail('Should throw');
        } catch (e) {
          expect(e.toString(), contains(error));
        }
        // Add a small delay to ensure events are processed
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // Verify event sequence
      expect(events, containsAllInOrder([
        isA<OperationInProgress>(), // First attempt
        isA<TokenAcquisitionFailed>(), // First failure
        isA<OperationInProgress>(), // Second attempt
        isA<TokenAcquisitionFailed>(), // Second failure
        isA<OperationInProgress>(), // Third attempt
        isA<TokenAcquisitionFailed>(), // Third failure
      ]));

      await subscription.cancel();
    });
  });
}
