import 'dart:convert';

import 'package:ever/domain/core/circuit_breaker.dart';
import 'package:ever/domain/core/local_cache.dart';
import 'package:ever/domain/core/retry_config.dart';
import 'package:ever/domain/entities/task.dart';
import 'package:ever/implementations/datasources/task_ds_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'task_ds_impl_test.mocks.dart';

@GenerateMocks([http.Client, LocalCache])
void main() {
  group('TaskDataSourceImpl', () {
    late MockClient mockClient;
    late MockLocalCache mockCache;
    late TaskDataSourceImpl dataSource;
    late RetryConfig retryConfig;
    late CircuitBreakerConfig circuitBreakerConfig;

    const accessToken = 'test_token';

    setUp(() {
      mockClient = MockClient();
      mockCache = MockLocalCache();
      retryConfig = RetryConfig.defaultConfig;
      circuitBreakerConfig = CircuitBreakerConfig(
        failureThreshold: 3,
        resetTimeout: Duration(seconds: 30),
        halfOpenMaxAttempts: 1,
      );

      dataSource = TaskDataSourceImpl(
        client: mockClient,
        cache: mockCache,
        retryConfig: retryConfig,
        circuitBreakerConfig: circuitBreakerConfig,
        getAccessToken: () => accessToken,
      );

      // Mock health check
      when(mockClient.get(
        any,
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response('', 200));
    });

    group('create', () {
      test('creates task successfully', () async {
        final task = Task(
          id: '',
          content: 'Test Task',
          status: TaskStatus.todo,
          priority: TaskPriority.medium,
          tags: ['test'],
        );

        final responseJson = {
          'data': {
            'id': 'task123',
            'content': task.content,
            'status': 'todo',
            'priority': 'medium',
            'tags': ['test'],
            'processing_status': 'pending',
            'enrichment_data': {},
          }
        };

        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          json.encode(responseJson),
          201,
        ));

        final result = await dataSource.create(task).first;

        expect(result.id, equals('task123'));
        expect(result.content, equals(task.content));
        expect(result.status, equals(task.status));
        expect(result.priority, equals(task.priority));
        expect(result.tags, equals(task.tags));
      });

      test('throws exception on non-201 response', () async {
        final task = Task(
          id: '',
          content: 'Test Task',
          status: TaskStatus.todo,
          priority: TaskPriority.medium,
          tags: ['test'],
        );

        when(mockClient.post(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          'Error creating task',
          400,
        ));

        expect(
          () => dataSource.create(task).first,
          throwsException,
        );
      });
    });

    group('update', () {
      test('updates task successfully', () async {
        final task = Task(
          id: 'task123',
          content: 'Updated Task',
          status: TaskStatus.inProgress,
          priority: TaskPriority.high,
          tags: ['test', 'updated'],
        );

        final responseJson = {
          'data': {
            'id': task.id,
            'content': task.content,
            'status': 'in_progress',
            'priority': 'high',
            'tags': ['test', 'updated'],
            'processing_status': 'pending',
            'enrichment_data': {},
          }
        };

        when(mockClient.put(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          json.encode(responseJson),
          200,
        ));

        final result = await dataSource.update(task).first;

        expect(result.id, equals(task.id));
        expect(result.content, equals(task.content));
        expect(result.status, equals(task.status));
        expect(result.priority, equals(task.priority));
        expect(result.tags, equals(task.tags));
      });

      test('throws exception on non-200 response', () async {
        final task = Task(
          id: 'task123',
          content: 'Updated Task',
          status: TaskStatus.inProgress,
          priority: TaskPriority.high,
          tags: ['test', 'updated'],
        );

        when(mockClient.put(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          'Error updating task',
          400,
        ));

        expect(
          () => dataSource.update(task).first,
          throwsException,
        );
      });
    });

    group('delete', () {
      test('deletes task successfully', () async {
        const taskId = 'task123';

        when(mockClient.delete(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          json.encode({'data': {'id': taskId}}),
          204,
        ));

        await expectLater(
          dataSource.delete(taskId),
          emitsInOrder([emitsDone]),
        );

        verify(mockClient.delete(
          any,
          headers: anyNamed('headers'),
        )).called(1);
      });

      test('throws exception on non-204 response', () async {
        const taskId = 'task123';

        when(mockClient.delete(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          'Error deleting task',
          400,
        ));

        expect(
          () => dataSource.delete(taskId).first,
          throwsException,
        );
      });
    });

    group('list', () {
      test('lists tasks successfully', () async {
        final responseJson = {
          'data': {
            'items': [
              {
                'id': 'task123',
                'content': 'Task 1',
                'status': 'todo',
                'priority': 'medium',
                'tags': ['test'],
                'processing_status': 'pending',
                'enrichment_data': {},
              },
              {
                'id': 'task456',
                'content': 'Task 2',
                'status': 'in_progress',
                'priority': 'high',
                'tags': ['test', 'important'],
                'processing_status': 'pending',
                'enrichment_data': {},
              },
            ]
          }
        };

        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          json.encode(responseJson),
          200,
        ));

        final result = await dataSource.list().first;

        expect(result, hasLength(2));
        expect(result[0].id, equals('task123'));
        expect(result[1].id, equals('task456'));
        expect(result[0].status, equals(TaskStatus.todo));
        expect(result[1].status, equals(TaskStatus.inProgress));
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          'Error listing tasks',
          400,
        ));

        expect(
          () => dataSource.list().first,
          throwsException,
        );
      });
    });

    group('read', () {
      test('reads task successfully', () async {
        const taskId = 'task123';
        final cachedData = {
          'id': taskId,
          'content': 'Test Task',
          'status': 'todo',
          'priority': 'medium',
          'tags': ['test'],
          'processing_status': 'pending',
          'enrichment_data': {},
        };

        // Mock cache operations
        when(mockCache.get('task:$taskId'))
            .thenAnswer((_) async => null); // First call returns null (cache cleared)
        when(mockCache.remove('task:$taskId'))
            .thenAnswer((_) async => true);

        // Mock API response
        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          json.encode({'data': cachedData}),
          200,
        ));

        final result = await dataSource.read(taskId).first;

        expect(result.id, equals(taskId));
        expect(result.content, equals('Test Task'));
        expect(result.status, equals(TaskStatus.todo));
        expect(result.priority, equals(TaskPriority.medium));
        expect(result.tags, equals(['test']));

        verify(mockCache.remove('task:$taskId')).called(1);
        verify(mockCache.get('task:$taskId')).called(1);
      });

      test('throws exception on non-200 response', () async {
        const taskId = 'task123';

        // Mock cache operations
        when(mockCache.get('task:$taskId'))
            .thenAnswer((_) async => null);
        when(mockCache.remove('task:$taskId'))
            .thenAnswer((_) async => true);

        // Mock API error response
        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          'Error reading task',
          404,
        ));

        await expectLater(
          () => dataSource.read(taskId).first,
          throwsException,
        );

        verifyInOrder([
          mockCache.remove('task:$taskId'),
          mockCache.get('task:$taskId'),
          mockClient.get(
            any,
            headers: anyNamed('headers'),
          ),
        ]);
      });
    });

    group('getByStatus', () {
      test('getByStatus gets tasks by status successfully', () async {
        final responseJson = {
          'data': [
            {
              'id': 'task123',
              'content': 'Task 1',
              'status': 'todo',
              'priority': 'medium',
              'tags': ['test'],
              'processing_status': 'pending',
              'enrichment_data': {},
            },
            {
              'id': 'task456',
              'content': 'Task 2',
              'status': 'todo',
              'priority': 'high',
              'tags': ['test'],
              'processing_status': 'pending',
              'enrichment_data': {},
            },
          ]
        };

        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          json.encode(responseJson),
          200,
        ));

        final result = await dataSource.getByStatus(TaskStatus.todo);

        expect(result, hasLength(2));
        expect(result[0].id, equals('task123'));
        expect(result[1].id, equals('task456'));
        expect(result[0].status, equals(TaskStatus.todo));
        expect(result[1].status, equals(TaskStatus.todo));
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          'Error getting tasks by status',
          400,
        ));

        expect(
          () => dataSource.getByStatus(TaskStatus.todo),
          throwsException,
        );
      });
    });

    group('getByPriority', () {
      test('getByPriority gets tasks by priority successfully', () async {
        final responseJson = {
          'data': [
            {
              'id': 'task123',
              'content': 'Task 1',
              'status': 'todo',
              'priority': 'high',
              'tags': ['test'],
              'processing_status': 'pending',
              'enrichment_data': {},
            },
            {
              'id': 'task456',
              'content': 'Task 2',
              'status': 'in_progress',
              'priority': 'high',
              'tags': ['test'],
              'processing_status': 'pending',
              'enrichment_data': {},
            },
          ]
        };

        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          json.encode(responseJson),
          200,
        ));

        final result = await dataSource.getByPriority(TaskPriority.high);

        expect(result, hasLength(2));
        expect(result[0].id, equals('task123'));
        expect(result[1].id, equals('task456'));
        expect(result[0].priority, equals(TaskPriority.high));
        expect(result[1].priority, equals(TaskPriority.high));
      });

      test('throws exception on non-200 response', () async {
        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          'Error getting tasks by priority',
          400,
        ));

        expect(
          () => dataSource.getByPriority(TaskPriority.high),
          throwsException,
        );
      });
    });

    group('getSubtasks', () {
      test('getSubtasks gets subtasks successfully', () async {
        const parentId = 'task123';
        final responseJson = {
          'data': [
            {
              'id': 'subtask1',
              'content': 'Subtask 1',
              'status': 'todo',
              'priority': 'medium',
              'tags': ['test'],
              'parent_id': parentId,
              'processing_status': 'pending',
              'enrichment_data': {},
            },
            {
              'id': 'subtask2',
              'content': 'Subtask 2',
              'status': 'in_progress',
              'priority': 'high',
              'tags': ['test'],
              'parent_id': parentId,
              'processing_status': 'pending',
              'enrichment_data': {},
            },
          ]
        };

        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          json.encode(responseJson),
          200,
        ));

        final result = await dataSource.getSubtasks(parentId);

        expect(result, hasLength(2));
        expect(result[0].id, equals('subtask1'));
        expect(result[1].id, equals('subtask2'));
        expect(result[0].parentId, equals(parentId));
        expect(result[1].parentId, equals(parentId));
      });

      test('throws exception on non-200 response', () async {
        const parentId = 'task123';

        when(mockClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(
          'Error getting subtasks',
          400,
        ));

        expect(
          () => dataSource.getSubtasks(parentId),
          throwsException,
        );
      });
    });

    group('updateStatus', () {
      test('updates task status successfully', () async {
        const taskId = 'task123';
        final responseJson = {
          'data': {
            'id': taskId,
            'content': 'Test Task',
            'status': 'in_progress',
            'priority': 'medium',
            'tags': ['test'],
            'processing_status': 'pending',
            'enrichment_data': {},
          }
        };

        when(mockClient.patch(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          json.encode(responseJson),
          200,
        ));

        final result = await dataSource.updateStatus(taskId, TaskStatus.inProgress);

        expect(result.id, equals(taskId));
        expect(result.status, equals(TaskStatus.inProgress));
      });

      test('throws exception on non-200 response', () async {
        const taskId = 'task123';

        when(mockClient.patch(
          any,
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        )).thenAnswer((_) async => http.Response(
          'Error updating task status',
          400,
        ));

        expect(
          () => dataSource.updateStatus(taskId, TaskStatus.inProgress),
          throwsException,
        );
      });
    });
  });
} 