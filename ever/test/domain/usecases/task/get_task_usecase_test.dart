import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/core/exceptions.dart';
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

    when(mockRepository.read(params.id))
        .thenAnswer((_) => Stream.empty());

    try {
      await useCase.execute(params);
      fail('Should throw TaskNotFoundException');
    } catch (e) {
      expect(e, isA<TaskNotFoundException>());
      expect(e.toString(), equals('TaskNotFoundException: Task not found: nonexistent'));
    }

    await Future.delayed(Duration(milliseconds: 100));
    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Task not found'));

    verify(mockRepository.read(params.id)).called(1);
  });

  test('handles network error', () async {
    const params = GetTaskParams(id: 'task123');

    final error = Exception('Network error');
    when(mockRepository.read(params.id))
        .thenAnswer((_) => Stream.error(error));

    try {
      await useCase.execute(params);
      fail('Should throw TaskNetworkException');
    } catch (e) {
      expect(e, isA<TaskNetworkException>());
      expect(e.toString(), equals('TaskNetworkException: Network error'));
    }

    await Future.delayed(Duration(milliseconds: 100));
    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Network error'));

    verify(mockRepository.read(params.id)).called(1);
  });

  test('validates task id', () async {
    const params = GetTaskParams(id: '');

    try {
      await useCase.execute(params);
      fail('Should throw TaskValidationException');
    } catch (e) {
      expect(e, isA<TaskValidationException>());
      expect(e.toString(), equals('TaskValidationException: Task ID cannot be empty'));
    }

    await Future.delayed(Duration(milliseconds: 100));
    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Task ID cannot be empty'));
    verifyNever(mockRepository.read(any));
  });
} 