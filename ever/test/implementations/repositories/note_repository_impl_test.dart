import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/core/retry_config.dart';
import 'package:ever/domain/core/circuit_breaker.dart';
import 'package:ever/domain/datasources/note_ds.dart';
import 'package:ever/implementations/repositories/note_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([NoteDataSource])
import 'note_repository_impl_test.mocks.dart';

void main() {
  late MockNoteDataSource mockDataSource;
  late NoteRepositoryImpl repository;
  late List<DomainEvent> events;
  late StreamSubscription<DomainEvent>? subscription;

  setUp(() {
    mockDataSource = MockNoteDataSource();
    
    // Default stub for events
    final defaultEventController = StreamController<DomainEvent>.broadcast();
    when(mockDataSource.events).thenAnswer((_) => defaultEventController.stream);
    
    repository = NoteRepositoryImpl(
      mockDataSource,
      circuitBreaker: CircuitBreaker(
        CircuitBreakerConfig(
          failureThreshold: 3,
          resetTimeout: const Duration(milliseconds: 100),
          halfOpenMaxAttempts: 1,
        ),
      ),
      retryConfig: RetryConfig(
        maxAttempts: 3,
        initialDelay: const Duration(milliseconds: 10),
        maxDelay: const Duration(milliseconds: 100),
        backoffFactor: 2.0,
      ),
    );
    events = [];
    subscription = repository.events.listen(events.add);
  });

  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    repository.dispose();
  });

  group('Note Repository Implementation', () {
    test('forwards events from data source', () async {
      // Clean up existing subscription
      await subscription?.cancel();
      
      final eventController = StreamController<DomainEvent>();
      when(mockDataSource.events).thenAnswer((_) => eventController.stream);

      // Recreate repository with new events stub
      repository = NoteRepositoryImpl(
        mockDataSource,
        circuitBreaker: CircuitBreaker(
          CircuitBreakerConfig(
            failureThreshold: 3,
            resetTimeout: const Duration(milliseconds: 100),
            halfOpenMaxAttempts: 1,
          ),
        ),
        retryConfig: RetryConfig(
          maxAttempts: 3,
          initialDelay: const Duration(milliseconds: 10),
          maxDelay: const Duration(milliseconds: 100),
          backoffFactor: 2.0,
        ),
      );
      events = [];
      subscription = repository.events.listen(events.add);

      final testEvent = OperationInProgress('test_operation');
      eventController.add(testEvent);
      
      // Wait for event processing
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(events, contains(testEvent));
      await eventController.close();
    });

    test('handles data source initialization', () async {
      when(mockDataSource.initialize()).thenAnswer((_) async {});
      await repository.initialize();
      verify(mockDataSource.initialize()).called(1);
    });

    test('handles data source disposal', () {
      when(mockDataSource.dispose()).thenReturn(null);
      repository.dispose();
      verify(mockDataSource.dispose()).called(1);
    });
  });
} 