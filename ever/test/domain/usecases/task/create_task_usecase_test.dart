import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/core/exceptions.dart';
import 'package:ever/domain/events/task_events.dart';
import 'package:ever/domain/entities/task.dart';
import 'package:ever/domain/repositories/task_repository.dart';
import 'package:ever/domain/usecases/task/create_task_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([TaskRepository])
import 'create_task_usecase_test.mocks.dart';

/// Test class for validating missing required parameters
class TestCreateTaskParams extends CreateTaskParams {
  final TaskStatus? _status;
  final TaskPriority? _priority;

  TestCreateTaskParams({
    super.content = 'Test Task',
    TaskStatus? status,
    TaskPriority? priority,
    super.tags,
  }) : _status = status,
       _priority = priority,
       super(
         status: TaskStatus.todo,
         priority: TaskPriority.medium,
       );

  @override
  String? validateWithMessage() {
    if (content.isEmpty) {
      return 'Content cannot be empty';
    }
    if (_status == null) {
      return 'Status is required';
    }
    if (_priority == null) {
      return 'Priority is required';
    }
    return null;
  }
}

void main() {
  late MockTaskRepository mockRepository;
  late CreateTaskUseCase useCase;
  late StreamSubscription<DomainEvent>? subscription;
  late List<DomainEvent> events;

  setUp(() {
    mockRepository = MockTaskRepository();
    useCase = CreateTaskUseCase(mockRepository);
    events = [];
    subscription = useCase.events.listen(events.add);
  });

  tearDown(() async {
    await subscription?.cancel();
    subscription = null;
    useCase.dispose();
  });

  Future<void> executeAndWait(CreateTaskParams params) async {
    useCase.execute(params);
    await Future.delayed(Duration.zero);
  }

  test('successful task creation', () async {
    final params = CreateTaskParams(
      content: 'Test Task',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      tags: const ['test'],
    );

    final createdTask = Task(
      id: 'task123',
      content: params.content,
      status: params.status,
      priority: params.priority,
      tags: params.tags ?? const [],
    );

    when(mockRepository.create(any)).thenAnswer(
      (_) => Stream.value(createdTask),
    );

    await executeAndWait(params);

    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('create_task'));
    expect(events[1], isA<TaskCreated>());
    expect((events[1] as TaskCreated).task, equals(createdTask));
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('create_task'));
  });

  test('handles creation failure', () async {
    final params = CreateTaskParams(
      content: 'Test Task',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      tags: const ['test'],
    );

    final error = Exception('Failed to create task');
    when(mockRepository.create(any))
        .thenAnswer((_) => Stream.error(error));

    try {
      await useCase.execute(params);
      fail('Should throw an exception');
    } catch (e) {
      expect(e, isA<TaskNetworkException>());
      expect(e.toString(), equals('TaskNetworkException: Failed to create task'));
    }

    await Future.delayed(Duration(milliseconds: 100));
    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('create_task'));
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Failed to create task'));
  });

  test('prevents concurrent creations', () async {
    final params = CreateTaskParams(
      content: 'Test Task',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      tags: const ['test'],
    );

    final completer = Completer<Task>();
    when(mockRepository.create(any))
        .thenAnswer((_) => Stream.fromFuture(completer.future));

    // First creation
    unawaited(useCase.execute(params));
    await Future.delayed(Duration.zero);

    // Try second creation while first is in progress
    expect(
      () => useCase.execute(params),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        'Creation already in progress'
      )),
    );
  });

  test('validates empty content', () async {
    final params = CreateTaskParams(
      content: '',
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
    );

    try {
      await useCase.execute(params);
      fail('Should throw TaskValidationException');
    } catch (e) {
      expect(e, isA<TaskValidationException>());
      expect(e.toString(), equals('TaskValidationException: Content cannot be empty'));
    }

    await Future.delayed(Duration(milliseconds: 100));
    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Content cannot be empty'));
    verifyNever(mockRepository.create(any));
  });

  test('validates missing status', () async {
    final params = TestCreateTaskParams(
      content: 'Test Task',
      status: null,
      priority: TaskPriority.medium,
    );

    try {
      await useCase.execute(params);
      fail('Should throw TaskValidationException');
    } catch (e) {
      expect(e, isA<TaskValidationException>());
      expect(e.toString(), equals('TaskValidationException: Status is required'));
    }

    await Future.delayed(Duration(milliseconds: 100));
    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Status is required'));
    verifyNever(mockRepository.create(any));
  });

  test('validates missing priority', () async {
    final params = TestCreateTaskParams(
      content: 'Test Task',
      status: TaskStatus.todo,
      priority: null,
    );

    try {
      await useCase.execute(params);
      fail('Should throw TaskValidationException');
    } catch (e) {
      expect(e, isA<TaskValidationException>());
      expect(e.toString(), equals('TaskValidationException: Priority is required'));
    }

    await Future.delayed(Duration(milliseconds: 100));
    expect(events, hasLength(2));
    expect(events[0], isA<OperationInProgress>());
    expect(events[1], isA<OperationFailure>());
    expect((events[1] as OperationFailure).error, equals('Priority is required'));
    verifyNever(mockRepository.create(any));
  });
} 