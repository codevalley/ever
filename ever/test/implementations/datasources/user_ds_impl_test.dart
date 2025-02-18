import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/core/retry_config.dart';
import 'package:ever/domain/core/retry_events.dart';
import 'package:ever/domain/core/circuit_breaker.dart';
import 'package:ever/domain/entities/user.dart';
import 'package:ever/implementations/config/api_config.dart';
import 'package:ever/implementations/config/error_messages.dart';
import 'package:ever/implementations/datasources/user_ds_impl.dart';
import 'package:ever/domain/core/local_cache.dart';

import 'user_ds_impl_test.mocks.dart';

@GenerateMocks([http.Client, LocalCache])
void main() {
  group('UserDataSourceImpl with Retry', () {
    late MockClient client;
    late MockLocalCache mockCache;
    late UserDataSourceImpl dataSource;
    late List<DomainEvent> emittedEvents;
    
    final testConfig = RetryConfig(
      maxAttempts: 3,
      initialDelay: Duration(milliseconds: 100),
      maxDelay: Duration(milliseconds: 500),
      backoffFactor: 2.0,
    );

    setUp(() {
      client = MockClient();
      mockCache = MockLocalCache();
      emittedEvents = [];

      // Setup cache mocks
      when(mockCache.initialize()).thenAnswer((_) async {});
      when(mockCache.get<String>('userSecret')).thenAnswer((_) async => null);
      when(mockCache.get<String>('accessToken')).thenAnswer((_) async => null);
      when(mockCache.get<String>('tokenExpiresAt')).thenAnswer((_) async => null);
      when(mockCache.set(any, any)).thenAnswer((_) async {});
      when(mockCache.clear()).thenAnswer((_) async {});

      // Create data source
      dataSource = UserDataSourceImpl(
        client: client,
        cache: mockCache,
        retryConfig: testConfig,
        circuitBreakerConfig: CircuitBreakerConfig(
          failureThreshold: 3,
          resetTimeout: Duration(milliseconds: 100),
          halfOpenMaxAttempts: 2,
        ),
      );

      // Listen to events
      dataSource.events.listen(emittedEvents.add);
    });

    test('should retry on network error and succeed', () async {
      final successResponse = http.Response(
        jsonEncode({
          ApiConfig.keys.common.data: {
            ApiConfig.keys.user.id: '123',
            ApiConfig.keys.auth.username: 'test_user',
            ApiConfig.keys.auth.userSecret: 'secret123',
            ApiConfig.keys.user.createdAt: DateTime.now().toIso8601String(),
          }
        }),
        201,
      );

      var attempts = 0;
      when(
        client.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts < 3) {
          throw http.ClientException(ErrorMessages.operation.networkError);
        }
        return successResponse;
      });

      // Execute registration and collect events
      final eventStream = dataSource.events.take(5);
      final resultStream = dataSource.register('test_user');
      
      // Wait for both streams to complete
      await Future.wait([
        expectLater(
          eventStream,
          emitsInOrder([
            isA<OperationInProgress>(),
            isA<RetryAttempt>(),
            isA<RetryAttempt>(),
            isA<RetrySuccess>(),
            isA<OperationSuccess>(),
          ]),
        ),
        expectLater(
          resultStream,
          emits(isA<User>()),
        ),
      ]);

      // Verify attempts
      expect(attempts, 3);
    });

    test('should retry on 5xx errors and succeed', () async {
      final errorResponse = http.Response(
        jsonEncode({
          ApiConfig.keys.common.message: 'Server Error'
        }),
        503,
      );
      final successResponse = http.Response(
        jsonEncode({
          ApiConfig.keys.common.data: {
            ApiConfig.keys.user.id: '123',
            ApiConfig.keys.auth.username: 'test_user',
            ApiConfig.keys.auth.accessToken: 'token123',
            ApiConfig.keys.user.createdAt: DateTime.now().toIso8601String(),
          }
        }),
        200,
      );

      var attempts = 0;
      when(
        client.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          await Future.delayed(Duration(milliseconds: 1));
          return errorResponse;
        }
        return successResponse;
      });

      // Execute token acquisition and wait for completion
      final stream = dataSource.obtainToken('secret123');
      final subscription = stream.listen(
        (_) {},
        onError: (error) {
          fail('Should not emit error: $error');
        },
      );

      // Wait for stream to complete
      await subscription.asFuture();
      await Future.delayed(Duration(milliseconds: 100));

      // Verify retry attempts and success
      expect(attempts, 2);
      expect(emittedEvents.whereType<RetryAttempt>().length, 1);
      expect(emittedEvents.whereType<RetrySuccess>().length, 1);
    });

    test('should exhaust retries and fail', () async {
      var attempts = 0;
      when(
        client.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async {
        attempts++;
        throw http.ClientException(ErrorMessages.operation.networkError);
      });

      // Execute registration and collect events
      final eventStream = dataSource.events.take(5);
      final resultStream = dataSource.register('test_user');
      
      // Wait for both streams to complete
      await Future.wait([
        expectLater(
          eventStream,
          emitsInOrder([
            isA<OperationInProgress>(),
            isA<RetryAttempt>(),
            isA<RetryAttempt>(),
            isA<RetryExhausted>(),
            isA<OperationFailure>(),
          ]),
        ),
        expectLater(
          resultStream,
          emitsError(predicate((e) => 
            e is http.ClientException && 
            e.message == ErrorMessages.operation.networkError
          )),
        ),
      ]);

      // Verify attempts
      expect(attempts, 3);
    });

    tearDown(() async {
      // Wait for any pending events to be processed
      await Future.delayed(Duration(milliseconds: 100));
    });
  });
} 