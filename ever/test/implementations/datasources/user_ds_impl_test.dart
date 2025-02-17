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
import 'package:ever/implementations/config/api_config.dart';
import 'package:ever/implementations/datasources/user_ds_impl.dart';
import 'package:ever/implementations/models/auth_credentials.dart';
import 'package:ever/implementations/models/user_model.dart';

import 'user_ds_impl_test.mocks.dart';

@GenerateMocks([http.Client, Isar])
void main() {
  group('UserDataSourceImpl with Retry', () {
    late MockClient client;
    late MockIsar isar;
    late MockIsarCollection collection;
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
      isar = MockIsar();
      collection = MockIsarCollection();
      emittedEvents = [];

      when(isar.collection<AuthCredentials>())
          .thenReturn(collection);

      dataSource = UserDataSourceImpl(
        isar: isar,
        client: client,
        retryConfig: testConfig,
      );

      dataSource.events.listen(emittedEvents.add);
    });

    test('should retry on network error and succeed', () async {
      final successResponse = http.Response(
        jsonEncode({
          'data': {
            'id': '123',
            'username': 'test_user',
            'user_secret': 'secret123',
            'created_at': DateTime.now().toIso8601String(),
          }
        }),
        201,
      );

      // Fail twice with network error, succeed on third attempt
      when(client.post(
        Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.auth.register}'),
        body: any,
        headers: any,
      )).thenAnswer((_) async {
        if (emittedEvents.whereType<RetryAttempt>().length < 2) {
          throw http.ClientException('Network error');
        }
        return successResponse;
      });

      // Execute registration
      final user = await dataSource.register('test_user').first;

      // Verify retry attempts
      expect(emittedEvents.whereType<RetryAttempt>().length, 2);
      expect(emittedEvents.whereType<RetrySuccess>().length, 1);
      
      // Verify final success
      expect(user.username, 'test_user');
      expect(emittedEvents.last, isA<OperationSuccess>());

      // Verify exponential backoff
      final retryAttempts = emittedEvents.whereType<RetryAttempt>().toList();
      expect(retryAttempts[0].delay, Duration(milliseconds: 100));
      expect(retryAttempts[1].delay, Duration(milliseconds: 200));
    });

    test('should retry on 5xx errors and succeed', () async {
      final errorResponse = http.Response('Server Error', 503);
      final successResponse = http.Response(
        jsonEncode({
          'data': {
            'id': '123',
            'username': 'test_user',
            'access_token': 'token123',
            'created_at': DateTime.now().toIso8601String(),
          }
        }),
        200,
      );

      when(client.post(
        Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.auth.token}'),
        body: any,
        headers: any,
      )).thenAnswer((_) async {
        if (emittedEvents.whereType<RetryAttempt>().length < 1) {
          return errorResponse;
        }
        return successResponse;
      });

      // Execute token acquisition
      final token = await dataSource.obtainToken('secret123').first;

      // Verify retry attempt and success
      expect(emittedEvents.whereType<RetryAttempt>().length, 1);
      expect(emittedEvents.whereType<RetrySuccess>().length, 1);
      expect(token, 'token123');
    });

    test('should exhaust retries and fail', () async {
      when(client.post(
        Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.auth.register}'),
        body: any,
        headers: any,
      )).thenAnswer((_) async {
        throw http.ClientException('Persistent network error');
      });

      // Execute and expect failure
      expect(
        () => dataSource.register('test_user').first,
        throwsA(isA<http.ClientException>()),
      );

      // Verify retry attempts and exhaustion
      expect(emittedEvents.whereType<RetryAttempt>().length, 2);
      expect(emittedEvents.whereType<RetryExhausted>().length, 1);
      expect(emittedEvents.last, isA<OperationFailure>());
    });

    test('should not retry on non-retryable errors', () async {
      final errorResponse = http.Response(
        jsonEncode({
          'message': 'Invalid username format'
        }),
        400,
      );

      when(client.post(
        Uri.parse('${ApiConfig.apiBaseUrl}${ApiConfig.endpoints.auth.register}'),
        body: any,
        headers: any,
      )).thenAnswer((_) async => errorResponse);

      // Execute and expect failure
      await expectLater(
        dataSource.register('invalid@user').first,
        throwsA(isA<String>()),
      );

      // Verify no retry attempts
      expect(emittedEvents.whereType<RetryAttempt>().isEmpty, true);
      expect(emittedEvents.last, isA<OperationFailure>());
    });
  });
} 