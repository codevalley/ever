import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/task_events.dart';
import 'package:ever/domain/repositories/task_repository.dart';
import 'package:ever/domain/usecases/task/delete_task_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([TaskRepository])
import 'delete_task_usecase_test.mocks.dart';

void main() {
  late MockTaskRepository mockRepository;
  late DeleteTaskUseCase useCase;
  late StreamSubscription<DomainEvent>? subscription;
  late List<DomainEvent> events;

  setUp(() {
    mockRepository = MockTaskRepository();
    useCase = DeleteTaskUseCase(mockRepository);
    events = [];
    subscription = useCase.events.listen(events.add);
  });

  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    await useCase.dispose();
  });

  test('successful task deletion', () async {
    const params = DeleteTaskParams(taskId: 'task123');

    when(mockRepository.delete(params.taskId))
        .thenAnswer((_) => Stream.value(null));

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('delete_task'));
    expect(events[1], isA<TaskDeleted>());
    expect((events[1] as TaskDeleted).taskId, equals(params.taskId));
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('delete_task'));
  });

  test('handles task not found', () async {
    const params = DeleteTaskParams(taskId: 'nonexistent');

    final error = Exception('Task not found');
    when(mockRepository.delete(params.taskId))
        .thenAnswer((_) => Stream.error(error));

    try {
      await useCase.execute(params);
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
    verify(mockRepository.delete(params.taskId)).called(greaterThanOrEqualTo(1));
  });

  test('handles network error with retries', () async {
    const params = DeleteTaskParams(taskId: 'task123');

    // Mock repository to fail with network error 3 times then succeed
    var attempts = 0;
    when(mockRepository.delete(params.taskId))
        .thenAnswer((_) {
          attempts++;
          if (attempts <= 3) {
            return Stream.error('Network error');
          }
          return Stream.value(null);
        });

    await useCase.execute(params);
    // Wait for all retries (100ms + 200ms + 300ms)
    await Future.delayed(Duration(milliseconds: 700));

    // Verify events sequence
    expect(events.length, equals(6));
    expect(events[0], isA<OperationInProgress>()); // Initial attempt
    expect(events[1], isA<OperationInProgress>()); // First retry
    expect(events[2], isA<OperationInProgress>()); // Second retry
    expect(events[3], isA<OperationInProgress>()); // Third retry
    expect(events[4], isA<TaskDeleted>());         // Success on fourth attempt
    expect(events[5], isA<OperationSuccess>());    // Final success

    // Verify repository was called 4 times
    verify(mockRepository.delete(params.taskId)).called(4);
  }, timeout: Timeout(Duration(seconds: 10)));

  test('handles network error exhausting retries', () async {
    const params = DeleteTaskParams(taskId: 'task123');

    // Mock repository to always fail with network error
    final error = Exception('Network error');
    when(mockRepository.delete(params.taskId))
        .thenAnswer((_) => Stream.error(error));

    try {
      await useCase.execute(params);
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
    verify(mockRepository.delete(params.taskId)).called(greaterThanOrEqualTo(1));
  }, timeout: Timeout(Duration(seconds: 10)));

  test('prevents concurrent deletions', () async {
    const params = DeleteTaskParams(taskId: 'task123');

    final completer = Completer<void>();
    when(mockRepository.delete(params.taskId))
        .thenAnswer((_) => Stream.fromFuture(completer.future));

    // First deletion
    unawaited(useCase.execute(params));
    await Future.delayed(Duration.zero);

    // Try second deletion while first is in progress
    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    // Complete first deletion
    completer.complete();
    await Future.delayed(Duration.zero);

    // Verify only one deletion was attempted
    verify(mockRepository.delete(params.taskId)).called(1);
    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('delete_task'));
    expect(events[1], isA<TaskDeleted>());
    expect(events[2], isA<OperationSuccess>());
  });

  test('validates task id', () async {
    const params = DeleteTaskParams(taskId: '');

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Task ID cannot be empty'));
    verifyNever(mockRepository.delete(any));
  });
} 