import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/core/exceptions.dart';
import 'package:ever/domain/events/task_events.dart';
import 'package:ever/domain/repositories/task_repository.dart';
import 'package:ever/domain/usecases/task/delete_task_usecase.dart';

@GenerateMocks([TaskRepository])
import 'delete_task_usecase_test.mocks.dart';

void main() {
  late DeleteTaskUseCase useCase;
  late MockTaskRepository repository;
  late List<DomainEvent> events;

  setUp(() {
    repository = MockTaskRepository();
    useCase = DeleteTaskUseCase(repository);
    events = [];
    useCase.events.listen(events.add);
  });

  tearDown(() async {
    await useCase.dispose();
  });

  test('validates empty task ID', () async {
    final params = DeleteTaskParams(taskId: '');
    
    expect(
      () => useCase.execute(params),
      throwsA(isA<StateError>()
          .having((e) => e.message, 'message', 'Task ID cannot be empty')),
    );

    await Future.delayed(Duration.zero);
    expect(events, [
      isA<OperationInProgress>()
          .having((e) => e.operation, 'operation', 'delete_task'),
      isA<OperationFailure>()
          .having((e) => e.operation, 'operation', 'delete_task')
          .having((e) => e.error, 'error', 'Task ID cannot be empty'),
    ]);
  });

  test('handles successful task deletion', () async {
    const taskId = 'task-123';
    final params = DeleteTaskParams(taskId: taskId);
    
    when(repository.delete(taskId))
        .thenAnswer((_) => Stream.fromIterable([null]));

    await useCase.execute(params);
    await Future.delayed(Duration.zero);

    expect(events, [
      isA<OperationInProgress>()
          .having((e) => e.operation, 'operation', 'delete_task'),
      isA<TaskDeleted>()
          .having((e) => e.taskId, 'taskId', taskId),
      isA<OperationSuccess>()
          .having((e) => e.operation, 'operation', 'delete_task'),
    ]);

    verify(repository.delete(taskId)).called(1);
  });

  test('handles task not found', () async {
    const taskId = 'nonexistent';
    final params = DeleteTaskParams(taskId: taskId);
    
    when(repository.delete(taskId))
        .thenAnswer((_) => Stream.error(TaskNotFoundException(taskId)));

    expect(
      () => useCase.execute(params),
      throwsA(isA<StateError>()
          .having((e) => e.message, 'message', 'Task not found')),
    );
    await Future.delayed(Duration.zero);

    expect(events, [
      isA<OperationInProgress>()
          .having((e) => e.operation, 'operation', 'delete_task'),
      isA<OperationFailure>()
          .having((e) => e.operation, 'operation', 'delete_task')
          .having((e) => e.error, 'error', 'Task not found'),
    ]);

    verify(repository.delete(taskId)).called(1);
  });

  test('handles network error with retries', () async {
    const taskId = 'task-123';
    final params = DeleteTaskParams(taskId: taskId);
    
    when(repository.delete(taskId))
        .thenAnswer((_) => Stream.error('Network error'));

    expect(
      () => useCase.execute(params),
      throwsA(isA<TaskNetworkException>()
          .having((e) => e.toString(), 'toString', 'TaskNetworkException: Network error')),
    );
    await Future.delayed(Duration(milliseconds: 500));

    expect(events, [
      isA<OperationInProgress>()
          .having((e) => e.operation, 'operation', 'delete_task'),
      isA<OperationInProgress>()
          .having((e) => e.operation, 'operation', 'delete_task'),
      isA<OperationInProgress>()
          .having((e) => e.operation, 'operation', 'delete_task'),
      isA<OperationFailure>()
          .having((e) => e.operation, 'operation', 'delete_task')
          .having((e) => e.error, 'error', 'Network error'),
    ]);

    verify(repository.delete(taskId)).called(3);
  });

  test('prevents concurrent deletions', () async {
    const taskId = 'task-123';
    final params = DeleteTaskParams(taskId: taskId);
    final completer = Completer<void>();
    final operationStarted = Completer<void>();
    
    when(repository.delete(taskId))
        .thenAnswer((_) {
          operationStarted.complete();
          return Stream.fromFuture(completer.future);
        });

    // Start first deletion
    unawaited(useCase.execute(params));
    await operationStarted.future;

    // Try to start second deletion
    expect(
      () => useCase.execute(params),
      throwsA(isA<StateError>()
          .having((e) => e.message, 'message', 'Task deletion already in progress')),
    );

    completer.complete();
    await Future.delayed(Duration.zero);
  });
} 