import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/task_events.dart';
import 'package:ever/domain/entities/task.dart';
import 'package:ever/domain/repositories/task_repository.dart';
import 'package:ever/domain/usecases/task/list_tasks_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([TaskRepository])
import 'list_tasks_usecase_test.mocks.dart';

void main() {
  late MockTaskRepository mockRepository;
  late ListTasksUseCase useCase;
  late StreamSubscription<DomainEvent>? subscription;
  late List<DomainEvent> events;

  setUp(() {
    mockRepository = MockTaskRepository();
    useCase = ListTasksUseCase(mockRepository);
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

  Future<void> executeAndWait(ListTasksParams params) async {
    useCase.execute(params);
    await Future.delayed(Duration.zero);
  }

  test('successful tasks listing', () async {
    final params = ListTasksParams(status: 'todo');

    final testTasks = [
      Task(
        id: 'task1',
        content: 'Content 1',
        status: TaskStatus.todo,
        priority: TaskPriority.medium,
        tags: ['test'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        processingStatus: ProcessingStatus.pending,
      ),
      Task(
        id: 'task2',
        content: 'Content 2',
        status: TaskStatus.todo,
        priority: TaskPriority.high,
        tags: ['test', 'important'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        processingStatus: ProcessingStatus.pending,
      ),
    ];

    when(mockRepository.list(filters: anyNamed('filters')))
        .thenAnswer((_) => Stream.value(testTasks));

    await executeAndWait(params);

    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('list_tasks'));
    expect(events[1], isA<TasksRetrieved>());
    expect((events[1] as TasksRetrieved).tasks, equals(testTasks));
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('list_tasks'));
  });

  test('handles empty list', () async {
    final params = ListTasksParams();

    when(mockRepository.list(filters: anyNamed('filters')))
        .thenAnswer((_) => Stream.value([]));

    await executeAndWait(params);

    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('list_tasks'));
    expect(events[1], isA<TasksRetrieved>());
    expect((events[1] as TasksRetrieved).tasks, isEmpty);
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('list_tasks'));
  });

  test('handles network error with retries', () async {
    final params = ListTasksParams();

    // Mock repository to always return error
    final error = Exception('Network error');
    when(mockRepository.list(filters: anyNamed('filters')))
        .thenAnswer((_) => Stream.error(error));

    // Execute and expect error
    try {
      await useCase.execute(params);
      fail('Should throw an exception');
    } catch (e) {
      expect(e.toString(), equals('Exception: Network error'));
    }

    // Wait for all events to be processed
    await Future.delayed(Duration(milliseconds: 500));

    // Verify events
    expect(events, [
      isA<OperationInProgress>(),
      isA<OperationInProgress>(),
      isA<OperationInProgress>(),
      isA<OperationFailure>(),
    ]);

    // Verify all events have correct operation name
    for (var event in events) {
      if (event is OperationInProgress) {
        expect(event.operation, equals('list_tasks'));
      } else if (event is OperationFailure) {
        expect(event.operation, equals('list_tasks'));
        expect(event.error, equals('Network error'));
      }
    }

    // Verify repository was called 3 times (initial + 2 retries)
    verify(mockRepository.list(filters: anyNamed('filters'))).called(3);
  });

  test('prevents concurrent listings', () async {
    final params = ListTasksParams(status: 'todo');

    final completer = Completer<List<Task>>();
    when(mockRepository.list(filters: anyNamed('filters')))
        .thenAnswer((_) => Stream.fromFuture(completer.future));

    // First listing
    useCase.execute(params);
    await Future.delayed(Duration.zero);

    // Try second listing while first is in progress
    expect(
      () => useCase.execute(params),
      throwsA(isA<StateError>().having(
        (e) => e.message,
        'message',
        'Listing already in progress'
      ))
    );
  });
} 