import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/task_events.dart';
import 'package:ever/domain/entities/task.dart';
import 'package:ever/domain/repositories/task_repository.dart';
import 'package:ever/domain/usecases/task/update_task_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([TaskRepository])
import 'update_task_usecase_test.mocks.dart';

void main() {
  late MockTaskRepository mockRepository;
  late UpdateTaskUseCase useCase;
  late StreamSubscription<DomainEvent>? subscription;
  late List<DomainEvent> events;

  setUp(() {
    mockRepository = MockTaskRepository();
    useCase = UpdateTaskUseCase(mockRepository);
    events = [];
    subscription = useCase.events.listen(events.add);
  });

  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    useCase.dispose();
  });

  Future<void> executeAndWait(UpdateTaskParams params) async {
    useCase.execute(params);
    await Future.delayed(Duration.zero);
  }

  test('validates empty task id', () async {
    final params = UpdateTaskParams(
      taskId: '',
      content: 'Updated Content',
    );

    await executeAndWait(params);

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Task ID cannot be empty'));
    verifyNever(mockRepository.read(any));
    verifyNever(mockRepository.update(any));
  });

  test('validates empty content', () async {
    final params = UpdateTaskParams(
      taskId: 'task123',
      content: '',
    );

    await executeAndWait(params);

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Content cannot be empty if provided'));
    verifyNever(mockRepository.read(any));
    verifyNever(mockRepository.update(any));
  });

  test('successful task update', () async {
    final params = UpdateTaskParams(
      taskId: 'task123',
      content: 'Updated Content',
      status: TaskStatus.inProgress,
      priority: TaskPriority.high,
      tags: ['test', 'updated'],
    );

    final existingTask = Task(
      id: params.taskId,
      content: 'Original Content',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      tags: ['test'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      processingStatus: ProcessingStatus.pending,
    );

    final updatedTask = Task(
      id: params.taskId,
      content: params.content!,
      status: params.status!,
      priority: params.priority!,
      tags: params.tags!,
      createdAt: existingTask.createdAt,
      updatedAt: DateTime.now(),
      processingStatus: existingTask.processingStatus,
    );

    when(mockRepository.read(params.taskId))
        .thenAnswer((_) => Stream.value(existingTask));

    when(mockRepository.update(any))
        .thenAnswer((_) => Stream.value(updatedTask));

    await executeAndWait(params);

    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('update_task'));
    expect(events[1], isA<TaskUpdated>());
    expect((events[1] as TaskUpdated).task, equals(updatedTask));
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('update_task'));
  });

  test('handles task not found', () async {
    final params = UpdateTaskParams(
      taskId: 'nonexistent',
      content: 'Updated Content',
    );

    final error = Exception('Task not found');
    when(mockRepository.read(params.taskId))
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
    verify(mockRepository.read(params.taskId)).called(greaterThanOrEqualTo(1));
  });

  test('handles network error with retries', () async {
    final params = UpdateTaskParams(
      taskId: 'task123',
      content: 'Updated Content',
    );

    final existingTask = Task(
      id: params.taskId,
      content: 'Original Content',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      tags: ['test'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      processingStatus: ProcessingStatus.pending,
    );

    final updatedTask = Task(
      id: params.taskId,
      content: params.content!,
      status: existingTask.status,
      priority: existingTask.priority,
      tags: existingTask.tags,
      createdAt: existingTask.createdAt,
      updatedAt: DateTime.now(),
      processingStatus: existingTask.processingStatus,
    );

    when(mockRepository.read(params.taskId))
        .thenAnswer((_) => Stream.value(existingTask));

    // Mock repository to fail with network error 3 times then succeed
    var attempts = 0;
    when(mockRepository.update(any))
        .thenAnswer((_) {
          attempts++;
          if (attempts <= 3) {
            return Stream.error('Network error');
          }
          return Stream.value(updatedTask);
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
    expect(events[4], isA<TaskUpdated>());         // Success on fourth attempt
    expect(events[5], isA<OperationSuccess>());    // Final success

    // Verify repository was called 4 times
    verify(mockRepository.update(any)).called(4);
  }, timeout: Timeout(Duration(seconds: 10)));

  test('handles network error exhausting retries', () async {
    final params = UpdateTaskParams(
      taskId: 'task123',
      content: 'Updated Content',
    );

    final existingTask = Task(
      id: params.taskId,
      content: 'Original Content',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      tags: ['test'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      processingStatus: ProcessingStatus.pending,
    );

    when(mockRepository.read(params.taskId))
        .thenAnswer((_) => Stream.value(existingTask));

    // Mock repository to always fail with network error
    final error = Exception('Network error');
    when(mockRepository.update(any))
        .thenAnswer((_) => Stream.error(error));

    // Execute and wait for completion or failure
    try {
      useCase.execute(params);
      await Future.delayed(Duration.zero);
      fail('Should throw an exception');
    } catch (e) {
      expect(e, equals(error));
    }

    // Wait for all retries to complete (100ms + 200ms + 300ms = 600ms)
    await Future.delayed(Duration(milliseconds: 600));

    // Verify events sequence
    expect(events.length, equals(5));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationInProgress>());
    expect(events[2], isA<OperationInProgress>());
    expect(events[3], isA<OperationInProgress>());
    expect(events[4], isA<OperationFailure>());
    expect((events[4] as OperationFailure).error, equals(error.toString()));

    // Verify repository was called 4 times (initial + 3 retries)
    verify(mockRepository.update(any)).called(4);
  }, timeout: Timeout(Duration(seconds: 10)));

  test('prevents concurrent updates', () async {
    final params = UpdateTaskParams(
      taskId: 'task123',
      content: 'Updated Content',
    );

    final existingTask = Task(
      id: params.taskId,
      content: 'Original Content',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      tags: ['test'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      processingStatus: ProcessingStatus.pending,
    );

    final readCompleter = Completer<Task>();
    final updateCompleter = Completer<Task>();

    when(mockRepository.read(params.taskId))
        .thenAnswer((_) => Stream.fromFuture(readCompleter.future));

    when(mockRepository.update(any))
        .thenAnswer((_) => Stream.fromFuture(updateCompleter.future));

    // First update
    useCase.execute(params);
    await Future.delayed(Duration.zero);

    // Try second update while first is in progress
    try {
      useCase.execute(params);
      fail('Should throw a StateError');
    } catch (e) {
      expect(e, isA<StateError>());
      expect(e.toString(), contains('Update already in progress'));
    }

    // Complete first update
    readCompleter.complete(existingTask);
    await Future.delayed(Duration.zero);

    final updatedTask = Task(
      id: params.taskId,
      content: params.content!,
      status: existingTask.status,
      priority: existingTask.priority,
      tags: existingTask.tags,
      createdAt: existingTask.createdAt,
      updatedAt: DateTime.now(),
      processingStatus: existingTask.processingStatus,
    );
    updateCompleter.complete(updatedTask);
    await Future.delayed(Duration.zero);

    // Verify only one update was attempted
    verify(mockRepository.update(any)).called(1);
    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('update_task'));
    expect(events[1], isA<TaskUpdated>());
    expect(events[2], isA<OperationSuccess>());
  });
} 