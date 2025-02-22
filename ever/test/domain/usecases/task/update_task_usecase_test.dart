import 'dart:async';

import 'package:ever/domain/core/exceptions.dart';
import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/entities/task.dart';
import 'package:ever/domain/events/task_events.dart';
import 'package:ever/domain/repositories/task_repository.dart';
import 'package:ever/domain/usecases/task/update_task_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([TaskRepository])
import 'update_task_usecase_test.mocks.dart';

void main() {
  late UpdateTaskUseCase useCase;
  late MockTaskRepository mockRepository;
  late List<DomainEvent> events;

  setUp(() {
    mockRepository = MockTaskRepository();
    useCase = UpdateTaskUseCase(mockRepository);
    events = [];
    useCase.events.listen(events.add);
  });

  test('validates empty task id', () async {
    final params = UpdateTaskParams(
      taskId: '',
      content: 'Updated Content',
    );

    expect(
      () => useCase.execute(params),
      throwsA(isA<StateError>()),
    );

    await Future.delayed(Duration(milliseconds: 100));
    expect(events.length, equals(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
  });

  test('validates empty content', () async {
    final params = UpdateTaskParams(
      taskId: 'task123',
      content: '',
    );

    expect(
      () => useCase.execute(params),
      throwsA(isA<StateError>()),
    );

    await Future.delayed(Duration(milliseconds: 100));
    expect(events.length, equals(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
  });

  test('successfully updates task', () async {
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

    when(mockRepository.update(any))
        .thenAnswer((_) => Stream.value(updatedTask));

    await useCase.execute(params);
    await Future.delayed(Duration(milliseconds: 100));

    expect(events.length, equals(3));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<TaskUpdated>());
    expect(events[2], isA<OperationSuccess>());

    verify(mockRepository.read(params.taskId)).called(1);
    verify(mockRepository.update(any)).called(1);
  });

  test('handles task not found', () async {
    final params = UpdateTaskParams(
      taskId: 'task123',
      content: 'Updated Content',
    );

    when(mockRepository.read(params.taskId))
        .thenAnswer((_) => Stream.error(TaskNotFoundException('Task not found')));

    expect(
      () => useCase.execute(params),
      throwsA(isA<StateError>()),
    );

    await Future.delayed(Duration(milliseconds: 100));
    expect(events.length, equals(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
  });

  test('handles network error', () async {
    final params = UpdateTaskParams(
      taskId: 'task123',
      content: 'Updated Content',
    );

    when(mockRepository.read(params.taskId))
        .thenAnswer((_) => Stream.error(TaskNetworkException('Network error')));

    expect(
      () => useCase.execute(params),
      throwsA(isA<TaskNetworkException>()),
    );

    await Future.delayed(Duration(milliseconds: 100));
    expect(events.length, equals(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
  });

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

    final completer = Completer<Task>();
    when(mockRepository.read(params.taskId))
        .thenAnswer((_) => Stream.fromFuture(
              Future.delayed(Duration(milliseconds: 100), () => existingTask)
            ));

    when(mockRepository.update(any))
        .thenAnswer((_) => Stream.fromFuture(completer.future));

    // Start first update
    unawaited(useCase.execute(params));
    await Future.delayed(Duration(milliseconds: 50));

    // Try concurrent update
    expect(
      () => useCase.execute(params),
      throwsA(isA<StateError>()),
    );

    await Future.delayed(Duration(milliseconds: 100));
    expect(events.whereType<OperationInProgress>().length, equals(1));

    // Complete the first update
    completer.complete(updatedTask);
    await Future.delayed(Duration(milliseconds: 100));
  });
} 