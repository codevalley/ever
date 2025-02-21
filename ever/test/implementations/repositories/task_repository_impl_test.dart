import 'dart:async';

import 'package:ever/domain/core/circuit_breaker.dart';
import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/core/retry_config.dart';
import 'package:ever/domain/datasources/task_ds.dart';
import 'package:ever/domain/entities/task.dart';
import 'package:ever/implementations/repositories/task_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'task_repository_impl_test.mocks.dart';

@GenerateMocks([TaskDataSource])
void main() {
  group('TaskRepositoryImpl', () {
    late MockTaskDataSource mockDataSource;
    late TaskRepositoryImpl repository;
    late RetryConfig retryConfig;
    late CircuitBreaker circuitBreaker;

    setUp(() {
      mockDataSource = MockTaskDataSource();
      retryConfig = RetryConfig.defaultConfig;
      circuitBreaker = CircuitBreaker(CircuitBreakerConfig(
        failureThreshold: 3,
        resetTimeout: const Duration(seconds: 30),
        halfOpenMaxAttempts: 1,
      ));

      // Mock data source events stream
      final eventController = StreamController<DomainEvent>.broadcast();
      when(mockDataSource.events).thenAnswer((_) => eventController.stream);

      repository = TaskRepositoryImpl(
        mockDataSource,
        circuitBreaker: circuitBreaker,
        retryConfig: retryConfig,
      );

      addTearDown(() {
        eventController.close();
      });
    });

    group('create', () {
      test('emits created task on successful creation', () async {
        final task = Task(
          id: '',
          content: 'Test Task',
          status: TaskStatus.todo,
          priority: TaskPriority.medium,
          tags: ['test'],
        );

        final createdTask = Task(
          id: 'task123',
          content: task.content,
          status: task.status,
          priority: task.priority,
          tags: task.tags,
        );

        when(mockDataSource.create(task)).thenAnswer(
          (_) => Stream.value(createdTask),
        );

        final result = await repository.create(task).first;

        expect(result.id, equals('task123'));
        expect(result.content, equals(task.content));
        expect(result.status, equals(task.status));
        expect(result.priority, equals(task.priority));
        expect(result.tags, equals(task.tags));
      });

      test('throws exception on data source error', () async {
        final task = Task(
          id: '',
          content: 'Test Task',
          status: TaskStatus.todo,
          priority: TaskPriority.medium,
          tags: ['test'],
        );

        when(mockDataSource.create(task)).thenAnswer(
          (_) => Stream.error(Exception('Failed to create task')),
        );

        expect(
          () => repository.create(task).first,
          throwsException,
        );
      });
    });

    group('update', () {
      test('emits updated task on successful update', () async {
        final task = Task(
          id: 'task123',
          content: 'Updated Task',
          status: TaskStatus.inProgress,
          priority: TaskPriority.high,
          tags: ['test', 'updated'],
        );

        when(mockDataSource.update(task)).thenAnswer(
          (_) => Stream.value(task),
        );

        final result = await repository.update(task).first;

        expect(result.id, equals(task.id));
        expect(result.content, equals(task.content));
        expect(result.status, equals(task.status));
        expect(result.priority, equals(task.priority));
        expect(result.tags, equals(task.tags));
      });

      test('throws exception on data source error', () async {
        final task = Task(
          id: 'task123',
          content: 'Updated Task',
          status: TaskStatus.inProgress,
          priority: TaskPriority.high,
          tags: ['test', 'updated'],
        );

        when(mockDataSource.update(task)).thenAnswer(
          (_) => Stream.error(Exception('Failed to update task')),
        );

        expect(
          () => repository.update(task).first,
          throwsException,
        );
      });
    });

    group('delete', () {
      test('completes successfully on successful deletion', () async {
        const taskId = 'task123';

        when(mockDataSource.delete(taskId)).thenAnswer(
          (_) => Stream.value(null),
        );

        await expectLater(
          repository.delete(taskId).first,
          completes,
        );
      });

      test('throws exception on data source error', () async {
        const taskId = 'task123';

        when(mockDataSource.delete(taskId)).thenAnswer(
          (_) => Stream.error(Exception('Failed to delete task')),
        );

        expect(
          () => repository.delete(taskId).first,
          throwsException,
        );
      });
    });

    group('list', () {
      test('emits list of tasks on successful fetch', () async {
        final tasks = [
          Task(
            id: 'task123',
            content: 'Task 1',
            status: TaskStatus.todo,
            priority: TaskPriority.medium,
            tags: ['test'],
          ),
          Task(
            id: 'task456',
            content: 'Task 2',
            status: TaskStatus.inProgress,
            priority: TaskPriority.high,
            tags: ['test', 'important'],
          ),
        ];

        when(mockDataSource.list(filters: anyNamed('filters'))).thenAnswer(
          (_) => Stream.value(tasks),
        );

        final result = await repository.list().first;

        expect(result, hasLength(2));
        expect(result[0].id, equals('task123'));
        expect(result[1].id, equals('task456'));
        expect(result[0].status, equals(TaskStatus.todo));
        expect(result[1].status, equals(TaskStatus.inProgress));
      });

      test('throws exception on data source error', () async {
        when(mockDataSource.list(filters: anyNamed('filters'))).thenAnswer(
          (_) => Stream.error(Exception('Failed to list tasks')),
        );

        expect(
          () => repository.list().first,
          throwsException,
        );
      });
    });

    group('read', () {
      test('emits task on successful fetch', () async {
        const taskId = 'task123';
        final task = Task(
          id: taskId,
          content: 'Test Task',
          status: TaskStatus.todo,
          priority: TaskPriority.medium,
          tags: ['test'],
        );

        when(mockDataSource.read(taskId)).thenAnswer(
          (_) => Stream.value(task),
        );

        final result = await repository.read(taskId).first;

        expect(result.id, equals(taskId));
        expect(result.content, equals(task.content));
        expect(result.status, equals(task.status));
        expect(result.priority, equals(task.priority));
        expect(result.tags, equals(task.tags));
      });

      test('throws exception on data source error', () async {
        const taskId = 'task123';

        when(mockDataSource.read(taskId)).thenAnswer(
          (_) => Stream.error(Exception('Failed to read task')),
        );

        expect(
          () => repository.read(taskId).first,
          throwsException,
        );
      });
    });

    group('getByStatus', () {
      test('returns tasks with specified status', () async {
        final tasks = [
          Task(
            id: 'task123',
            content: 'Task 1',
            status: TaskStatus.todo,
            priority: TaskPriority.medium,
            tags: ['test'],
          ),
          Task(
            id: 'task456',
            content: 'Task 2',
            status: TaskStatus.todo,
            priority: TaskPriority.high,
            tags: ['test'],
          ),
        ];

        when(mockDataSource.getByStatus(TaskStatus.todo)).thenAnswer(
          (_) async => tasks,
        );

        final result = await repository.getByStatus(TaskStatus.todo);

        expect(result, hasLength(2));
        expect(result[0].status, equals(TaskStatus.todo));
        expect(result[1].status, equals(TaskStatus.todo));
      });

      test('throws exception on data source error', () async {
        when(mockDataSource.getByStatus(TaskStatus.todo)).thenThrow(
          Exception('Failed to get tasks by status'),
        );

        expect(
          () => repository.getByStatus(TaskStatus.todo),
          throwsException,
        );
      });
    });

    group('getByPriority', () {
      test('returns tasks with specified priority', () async {
        final tasks = [
          Task(
            id: 'task123',
            content: 'Task 1',
            status: TaskStatus.todo,
            priority: TaskPriority.high,
            tags: ['test'],
          ),
          Task(
            id: 'task456',
            content: 'Task 2',
            status: TaskStatus.inProgress,
            priority: TaskPriority.high,
            tags: ['test'],
          ),
        ];

        when(mockDataSource.getByPriority(TaskPriority.high)).thenAnswer(
          (_) async => tasks,
        );

        final result = await repository.getByPriority(TaskPriority.high);

        expect(result, hasLength(2));
        expect(result[0].priority, equals(TaskPriority.high));
        expect(result[1].priority, equals(TaskPriority.high));
      });

      test('throws exception on data source error', () async {
        when(mockDataSource.getByPriority(TaskPriority.high)).thenThrow(
          Exception('Failed to get tasks by priority'),
        );

        expect(
          () => repository.getByPriority(TaskPriority.high),
          throwsException,
        );
      });
    });

    group('getSubtasks', () {
      test('returns subtasks for given task', () async {
        const parentId = 'task123';
        final tasks = [
          Task(
            id: 'subtask1',
            content: 'Subtask 1',
            status: TaskStatus.todo,
            priority: TaskPriority.medium,
            tags: ['test'],
            parentId: parentId,
          ),
          Task(
            id: 'subtask2',
            content: 'Subtask 2',
            status: TaskStatus.inProgress,
            priority: TaskPriority.high,
            tags: ['test'],
            parentId: parentId,
          ),
        ];

        when(mockDataSource.getSubtasks(parentId)).thenAnswer(
          (_) async => tasks,
        );

        final result = await repository.getSubtasks(parentId);

        expect(result, hasLength(2));
        expect(result[0].parentId, equals(parentId));
        expect(result[1].parentId, equals(parentId));
      });

      test('throws exception on data source error', () async {
        const parentId = 'task123';

        when(mockDataSource.getSubtasks(parentId)).thenThrow(
          Exception('Failed to get subtasks'),
        );

        expect(
          () => repository.getSubtasks(parentId),
          throwsException,
        );
      });
    });

    group('updateStatus', () {
      test('updates task status successfully', () async {
        const taskId = 'task123';
        final task = Task(
          id: taskId,
          content: 'Test Task',
          status: TaskStatus.inProgress,
          priority: TaskPriority.medium,
          tags: ['test'],
        );

        when(mockDataSource.updateStatus(taskId, TaskStatus.inProgress)).thenAnswer(
          (_) async => task,
        );

        final result = await repository.updateStatus(taskId, TaskStatus.inProgress);

        expect(result.id, equals(taskId));
        expect(result.status, equals(TaskStatus.inProgress));
      });

      test('throws exception on data source error', () async {
        const taskId = 'task123';

        when(mockDataSource.updateStatus(taskId, TaskStatus.inProgress)).thenThrow(
          Exception('Failed to update task status'),
        );

        expect(
          () => repository.updateStatus(taskId, TaskStatus.inProgress),
          throwsException,
        );
      });
    });
  });
} 