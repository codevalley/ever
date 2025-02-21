import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/task_events.dart';
import 'package:ever/domain/entities/task.dart';
import 'package:ever/domain/repositories/task_repository.dart';
import 'package:ever/domain/usecases/task/get_task_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([TaskRepository])
import 'get_task_usecase_test.mocks.dart';

void main() {
  late MockTaskRepository mockRepository;
  late GetTaskUseCase useCase;
  late StreamSubscription<DomainEvent>? subscription;
  late List<DomainEvent> events;

  setUp(() {
    mockRepository = MockTaskRepository();
    useCase = GetTaskUseCase(mockRepository);
    events = [];
    subscription = useCase.events.listen((event) {
      events.add(event);
    });
  });

  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    useCase.dispose();
  });

  Future<void> executeAndWait(GetTaskParams params) async {
    useCase.execute(params);
    await Future.delayed(Duration.zero);
  }

  test('successful task retrieval', () async {
    const params = GetTaskParams(id: 'task123');

    final testTask = Task(
      id: params.id,
      content: 'Test Task',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      tags: ['test'],
    );

    when(mockRepository.read(params.id))
        .thenAnswer((_) => Stream.value(testTask));

    await executeAndWait(params);

    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('get_task'));
    expect(events[1], isA<TaskRetrieved>());
    expect((events[1] as TaskRetrieved).task, equals(testTask));
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('get_task'));
  });

  test('handles task not found', () async {
    const params = GetTaskParams(id: 'nonexistent');

    final error = Exception('Task not found');
    when(mockRepository.read(params.id))
        .thenAnswer((_) => Stream.error(error));

    try {
      useCase.execute(params);
      await Future.delayed(Duration.zero);
      fail('Should throw an exception');
    } catch (e) {
      expect(e.toString(), equals(error.toString()));
    }

    // Wait for all retries to complete
    await Future.delayed(Duration(milliseconds: 700));

    // Verify events
    expect(events.length, greaterThanOrEqualTo(2));
    expect(events.first, isA<OperationInProgress>());
    expect(events.last, isA<OperationFailure>());
    expect((events.last as OperationFailure).error, equals(error.toString()));

    // Count OperationInProgress events (should be 1 initial + up to 3 retries)
    var progressEvents = events.whereType<OperationInProgress>().length;
    expect(progressEvents, greaterThanOrEqualTo(1));
    expect(progressEvents, lessThanOrEqualTo(4));

    // Verify repository was called at least once
    verify(mockRepository.read(params.id)).called(greaterThanOrEqualTo(1));
  });

  test('handles network error with retries', () async {
    const params = GetTaskParams(id: 'task123');

    // Mock repository to fail with network error 3 times then succeed
    var attempts = 0;
    final testTask = Task(
      id: params.id,
      content: 'Test Task',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      tags: ['test'],
    );

    when(mockRepository.read(params.id))
        .thenAnswer((_) {
          attempts++;
          if (attempts <= 3) {
            return Stream.error('Network error');
          }
          return Stream.value(testTask);
        });

    useCase.execute(params);
    // Wait for all retries (100ms + 200ms + 300ms)
    await Future.delayed(Duration(milliseconds: 700));

    // Verify events sequence
    expect(events.length, equals(6));
    expect(events[0], isA<OperationInProgress>()); // Initial attempt
    expect(events[1], isA<OperationInProgress>()); // First retry
    expect(events[2], isA<OperationInProgress>()); // Second retry
    expect(events[3], isA<OperationInProgress>()); // Third retry
    expect(events[4], isA<TaskRetrieved>());       // Success on fourth attempt
    expect(events[5], isA<OperationSuccess>());    // Final success

    // Verify repository was called 4 times
    verify(mockRepository.read(params.id)).called(4);
  }, timeout: Timeout(Duration(seconds: 10)));

  test('handles network error exhausting retries', () async {
    const params = GetTaskParams(id: 'task123');

    // Mock repository to always fail with network error
    final error = Exception('Network error');
    when(mockRepository.read(params.id))
        .thenAnswer((_) => Stream.error(error));

    try {
      useCase.execute(params);
      await Future.delayed(Duration.zero);
      fail('Should throw an exception');
    } catch (e) {
      expect(e.toString(), equals(error.toString()));
    }

    // Wait for all retries to complete
    await Future.delayed(Duration(milliseconds: 700));

    // Verify events
    expect(events.length, greaterThanOrEqualTo(2));
    expect(events.first, isA<OperationInProgress>());
    expect(events.last, isA<OperationFailure>());
    expect((events.last as OperationFailure).error, equals(error.toString()));

    // Count OperationInProgress events (should be 1 initial + up to 3 retries)
    var progressEvents = events.whereType<OperationInProgress>().length;
    expect(progressEvents, greaterThanOrEqualTo(1));
    expect(progressEvents, lessThanOrEqualTo(4));

    // Verify repository was called at least once
    verify(mockRepository.read(params.id)).called(greaterThanOrEqualTo(1));
  }, timeout: Timeout(Duration(seconds: 10)));

  test('validates task id', () async {
    const params = GetTaskParams(id: '');

    await executeAndWait(params);

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Task ID cannot be empty'));
    verifyNever(mockRepository.read(any));
  });
} 