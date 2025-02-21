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
    final params = ListTasksParams(filters: {'status': 'todo'});

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
      useCase.execute(params);
      await Future.delayed(Duration.zero);
      fail('Should throw an exception');
    } catch (e) {
      expect(e, equals(error));
    }

    // Wait for events to be processed
    await Future.delayed(Duration(milliseconds: 100));

    // Verify at least one OperationInProgress and one OperationFailure
    expect(events.length, greaterThanOrEqualTo(2));
    expect(events.first, isA<OperationInProgress>());
    expect(events.last, isA<OperationFailure>());
    expect((events.last as OperationFailure).error, equals(error.toString()));

    // Count OperationInProgress events
    var progressEvents = events.whereType<OperationInProgress>().length;
    expect(progressEvents, greaterThanOrEqualTo(1));

    // Verify repository was called at least once
    verify(mockRepository.list(filters: anyNamed('filters'))).called(greaterThanOrEqualTo(1));
  });

  test('prevents concurrent listings', () async {
    final params = ListTasksParams(filters: {'status': 'todo'});

    final completer = Completer<List<Task>>();
    when(mockRepository.list(filters: anyNamed('filters')))
        .thenAnswer((_) => Stream.fromFuture(completer.future));

    // First listing
    useCase.execute(params);
    await Future.delayed(Duration.zero);

    // Try second listing while first is in progress
    try {
      useCase.execute(params);
      fail('Should throw a StateError');
    } catch (e) {
      expect(e, isA<StateError>());
      expect(e.toString(), contains('Listing already in progress'));
    }

    // Complete first listing
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
    ];
    completer.complete(testTasks);
    await Future.delayed(Duration.zero);

    // Verify only one listing was attempted
    verify(mockRepository.list(filters: anyNamed('filters'))).called(1);
    expect(events, hasLength(3));
    expect(events[0], isA<OperationInProgress>());
    expect((events[0] as OperationInProgress).operation, equals('list_tasks'));
    expect(events[1], isA<TasksRetrieved>());
    expect(events[2], isA<OperationSuccess>());
    expect((events[2] as OperationSuccess).operation, equals('list_tasks'));
  });
} 