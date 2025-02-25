import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/user_events.dart';
import 'package:ever/domain/entities/user.dart';
import 'package:ever/domain/entities/note.dart' as note_entity;
import 'package:ever/domain/entities/task.dart';
import 'package:ever/domain/presenter/ever_presenter.dart';
import 'package:ever/domain/usecases/note/create_note_usecase.dart';
import 'package:ever/domain/usecases/note/update_note_usecase.dart';
import 'package:ever/domain/usecases/note/delete_note_usecase.dart';
import 'package:ever/domain/usecases/note/list_notes_usecase.dart';
import 'package:ever/domain/usecases/note/get_note_usecase.dart';
import 'package:ever/domain/usecases/user/get_current_user_usecase.dart';
import 'package:ever/domain/usecases/user/login_usecase.dart';
import 'package:ever/domain/usecases/user/refresh_token_usecase.dart';
import 'package:ever/domain/usecases/user/register_usecase.dart';
import 'package:ever/domain/usecases/user/sign_out_usecase.dart';
import 'package:ever/domain/usecases/task/create_task_usecase.dart';
import 'package:ever/domain/usecases/task/update_task_usecase.dart';
import 'package:ever/domain/usecases/task/delete_task_usecase.dart';
import 'package:ever/domain/usecases/task/list_tasks_usecase.dart';
import 'package:ever/domain/usecases/task/get_task_usecase.dart';
import 'package:ever/implementations/presenter/flutter_ever_presenter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'flutter_ever_presenter_test.mocks.dart';

@GenerateMocks([
  RegisterUseCase,
  LoginUseCase,
  SignOutUseCase,
  RefreshTokenUseCase,
  GetCurrentUserUseCase,
  CreateNoteUseCase,
  UpdateNoteUseCase,
  DeleteNoteUseCase,
  ListNotesUseCase,
  GetNoteUseCase,
  CreateTaskUseCase,
  UpdateTaskUseCase,
  DeleteTaskUseCase,
  ListTasksUseCase,
  GetTaskUseCase,
])
void main() {
  late MockRegisterUseCase mockRegisterUseCase;
  late MockLoginUseCase mockLoginUseCase;
  late MockSignOutUseCase mockSignOutUseCase;
  late MockRefreshTokenUseCase mockRefreshTokenUseCase;
  late MockGetCurrentUserUseCase mockGetCurrentUserUseCase;
  late MockCreateNoteUseCase mockCreateNoteUseCase;
  late MockUpdateNoteUseCase mockUpdateNoteUseCase;
  late MockDeleteNoteUseCase mockDeleteNoteUseCase;
  late MockListNotesUseCase mockListNotesUseCase;
  late MockGetNoteUseCase mockGetNoteUseCase;
  late MockCreateTaskUseCase mockCreateTaskUseCase;
  late MockUpdateTaskUseCase mockUpdateTaskUseCase;
  late MockDeleteTaskUseCase mockDeleteTaskUseCase;
  late MockListTasksUseCase mockListTasksUseCase;
  late MockGetTaskUseCase mockGetTaskUseCase;
  late FlutterEverPresenter presenter;
  late List<EverState> states;
  late StreamController<DomainEvent> registerEventController;
  late StreamController<DomainEvent> loginEventController;
  late StreamController<DomainEvent> signOutEventController;
  late StreamController<DomainEvent> refreshTokenEventController;
  late StreamController<DomainEvent> getCurrentUserEventController;
  late StreamController<DomainEvent> createNoteEventController;
  late StreamController<DomainEvent> updateNoteEventController;
  late StreamController<DomainEvent> deleteNoteEventController;
  late StreamController<DomainEvent> listNotesEventController;
  late StreamController<DomainEvent> getNoteEventController;
  late StreamController<DomainEvent> createTaskEventController;
  late StreamController<DomainEvent> updateTaskEventController;
  late StreamController<DomainEvent> deleteTaskEventController;
  late StreamController<DomainEvent> listTasksEventController;
  late StreamController<DomainEvent> getTaskEventController;
  late StreamSubscription<EverState>? stateSubscription;

  setUp(() async {
    mockRegisterUseCase = MockRegisterUseCase();
    mockLoginUseCase = MockLoginUseCase();
    mockSignOutUseCase = MockSignOutUseCase();
    mockRefreshTokenUseCase = MockRefreshTokenUseCase();
    mockGetCurrentUserUseCase = MockGetCurrentUserUseCase();
    mockCreateNoteUseCase = MockCreateNoteUseCase();
    mockUpdateNoteUseCase = MockUpdateNoteUseCase();
    mockDeleteNoteUseCase = MockDeleteNoteUseCase();
    mockListNotesUseCase = MockListNotesUseCase();
    mockGetNoteUseCase = MockGetNoteUseCase();
    mockCreateTaskUseCase = MockCreateTaskUseCase();
    mockUpdateTaskUseCase = MockUpdateTaskUseCase();
    mockDeleteTaskUseCase = MockDeleteTaskUseCase();
    mockListTasksUseCase = MockListTasksUseCase();
    mockGetTaskUseCase = MockGetTaskUseCase();

    registerEventController = StreamController<DomainEvent>();
    loginEventController = StreamController<DomainEvent>();
    signOutEventController = StreamController<DomainEvent>();
    refreshTokenEventController = StreamController<DomainEvent>();
    getCurrentUserEventController = StreamController<DomainEvent>();
    createNoteEventController = StreamController<DomainEvent>();
    updateNoteEventController = StreamController<DomainEvent>();
    deleteNoteEventController = StreamController<DomainEvent>();
    listNotesEventController = StreamController<DomainEvent>();
    getNoteEventController = StreamController<DomainEvent>();
    createTaskEventController = StreamController<DomainEvent>();
    updateTaskEventController = StreamController<DomainEvent>();
    deleteTaskEventController = StreamController<DomainEvent>();
    listTasksEventController = StreamController<DomainEvent>();
    getTaskEventController = StreamController<DomainEvent>();

    when(mockRegisterUseCase.events).thenAnswer((_) => registerEventController.stream);
    when(mockLoginUseCase.events).thenAnswer((_) => loginEventController.stream);
    when(mockSignOutUseCase.events).thenAnswer((_) => signOutEventController.stream);
    when(mockRefreshTokenUseCase.events).thenAnswer((_) => refreshTokenEventController.stream);
    when(mockGetCurrentUserUseCase.events).thenAnswer((_) => getCurrentUserEventController.stream);
    when(mockCreateNoteUseCase.events).thenAnswer((_) => createNoteEventController.stream);
    when(mockUpdateNoteUseCase.events).thenAnswer((_) => updateNoteEventController.stream);
    when(mockDeleteNoteUseCase.events).thenAnswer((_) => deleteNoteEventController.stream);
    when(mockListNotesUseCase.events).thenAnswer((_) => listNotesEventController.stream);
    when(mockGetNoteUseCase.events).thenAnswer((_) => getNoteEventController.stream);
    when(mockCreateTaskUseCase.events).thenAnswer((_) => createTaskEventController.stream);
    when(mockUpdateTaskUseCase.events).thenAnswer((_) => updateTaskEventController.stream);
    when(mockDeleteTaskUseCase.events).thenAnswer((_) => deleteTaskEventController.stream);
    when(mockListTasksUseCase.events).thenAnswer((_) => listTasksEventController.stream);
    when(mockGetTaskUseCase.events).thenAnswer((_) => getTaskEventController.stream);

    presenter = FlutterEverPresenter(
      registerUseCase: mockRegisterUseCase,
      loginUseCase: mockLoginUseCase,
      signOutUseCase: mockSignOutUseCase,
      refreshTokenUseCase: mockRefreshTokenUseCase,
      getCurrentUserUseCase: mockGetCurrentUserUseCase,
      createNoteUseCase: mockCreateNoteUseCase,
      updateNoteUseCase: mockUpdateNoteUseCase,
      deleteNoteUseCase: mockDeleteNoteUseCase,
      listNotesUseCase: mockListNotesUseCase,
      getNoteUseCase: mockGetNoteUseCase,
      createTaskUseCase: mockCreateTaskUseCase,
      updateTaskUseCase: mockUpdateTaskUseCase,
      deleteTaskUseCase: mockDeleteTaskUseCase,
      listTasksUseCase: mockListTasksUseCase,
      getTaskUseCase: mockGetTaskUseCase,
    );

    states = [];
    stateSubscription = presenter.state.listen(states.add);
    await Future.delayed(Duration.zero);
  });

  tearDown(() async {
    await stateSubscription?.cancel();
    stateSubscription = null;
    await presenter.dispose();

    // Close all event controllers
    final controllers = [
      registerEventController,
      loginEventController,
      signOutEventController,
      refreshTokenEventController,
      getCurrentUserEventController,
      createNoteEventController,
      updateNoteEventController,
      deleteNoteEventController,
      listNotesEventController,
      getNoteEventController,
      createTaskEventController,
      updateTaskEventController,
      deleteTaskEventController,
      listTasksEventController,
      getTaskEventController,
    ];

    for (final controller in controllers) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  });

  Matcher isEverState({
    bool? isLoading,
    User? currentUser,
    bool? isAuthenticated,
    String? error,
  }) {
    return isA<EverState>()
        .having((s) => s.isLoading, 'isLoading', isLoading ?? false)
        .having((s) => s.currentUser, 'currentUser', currentUser)
        .having((s) => s.isAuthenticated, 'isAuthenticated', isAuthenticated ?? false)
        .having((s) => s.error, 'error', error);
  }

  Future<void> pumpEventQueue() async {
    await Future.delayed(Duration.zero);
  }

  group('initialization', () {
    test('starts with initial state', () async {
      expect(states, [
        isEverState(),
      ]);
    });
  });

  group('registration', () {
    test('executes register use case with correct parameters', () async {
      await presenter.register('testuser');
      await pumpEventQueue();

      verify(mockRegisterUseCase.execute(argThat(
        isA<RegisterParams>().having((p) => p.username, 'username', 'testuser'),
      ))).called(1);
    });

    test('updates state during registration flow', () async {
      await presenter.register('testuser');
      await pumpEventQueue();
      registerEventController.add(OperationInProgress('register'));
      await pumpEventQueue();

      expect(states, [
        isEverState(),
        isEverState(isLoading: true),
      ]);
    });

    test('handles registration failure', () async {
      await presenter.register('testuser');
      await pumpEventQueue();
      registerEventController.add(OperationInProgress('register'));
      await pumpEventQueue();
      registerEventController.add(OperationFailure('register', 'Username taken'));
      await pumpEventQueue();

      expect(states, [
        isEverState(),
        isEverState(isLoading: true),
        isEverState(error: 'Username taken'),
      ]);
    });
  });

  group('login', () {
    late List<EverState> states;
    late StreamSubscription<EverState> stateSubscription;

    setUp(() {
      states = [];
      stateSubscription = presenter.state.listen(states.add);
    });

    tearDown(() {
      stateSubscription.cancel();
    });

    test('login executes login use case with correct parameters', () async {
      // Arrange
      final userSecret = 'test-secret';
      final user = User(
        id: '1', 
        username: 'Test User',
        createdAt: DateTime.now(),
      );
      
      // Act
      await presenter.login(userSecret);
      
      // Assert initial state
      verify(mockLoginUseCase.execute(any)).called(1);
      expect(states.any((s) => s.isLoading), isTrue);
      expect(states.last.error, isNull);
      
      // Emit token obtained
      loginEventController.add(TokenObtained('test-token', DateTime.now().add(Duration(hours: 1))));
      await pumpEventQueue();
      
      // Verify getCurrentUser is called
      verify(mockGetCurrentUserUseCase.execute()).called(1);
      
      // Emit user retrieved
      getCurrentUserEventController.add(CurrentUserRetrieved(user));
      await pumpEventQueue();
      
      // Assert final state
      expect(states.last.isLoading, isFalse);
      expect(states.last.currentUser, equals(user));
      expect(states.last.isAuthenticated, isTrue);
      expect(states.last.error, isNull);
    });

    test('login handles login failure', () async {
      // Arrange
      final userSecret = 'test-secret';
      final error = 'Login failed';
      
      // Act
      await presenter.login(userSecret);
      
      // Assert initial state
      verify(mockLoginUseCase.execute(any)).called(1);
      expect(states.any((s) => s.isLoading), isTrue);
      expect(states.last.error, isNull);
      
      // Emit failure
      loginEventController.add(OperationFailure('login', error));
      await pumpEventQueue();
      
      // Assert final state
      expect(states.last.isLoading, isFalse);
      expect(states.last.error, equals(error));
      expect(states.last.isAuthenticated, isFalse);
      expect(states.last.currentUser, isNull);
    });

    test('login handles user info failure', () async {
      // Arrange
      final userSecret = 'test-secret';
      final error = 'Failed to get user info';
      
      // Act
      await presenter.login(userSecret);
      
      // Assert initial state
      verify(mockLoginUseCase.execute(any)).called(1);
      expect(states.any((s) => s.isLoading), isTrue);
      expect(states.last.error, isNull);
      
      // Emit token obtained
      loginEventController.add(TokenObtained('test-token', DateTime.now().add(Duration(hours: 1))));
      await pumpEventQueue();
      
      // Verify getCurrentUser is called
      verify(mockGetCurrentUserUseCase.execute()).called(1);
      
      // Emit user info failure
      getCurrentUserEventController.add(OperationFailure('get_user', error));
      await pumpEventQueue();
      
      // Assert final state
      expect(states.last.isLoading, isFalse);
      expect(states.last.error, equals(error));
      expect(states.last.isAuthenticated, isFalse);
      expect(states.last.currentUser, isNull);
    });
  });

  group('token management', () {
    test('updates state when token expires', () async {
      final user = User(
        id: '1',
        username: 'testuser',
        createdAt: DateTime.now(),
      );
      getCurrentUserEventController.add(CurrentUserRetrieved(user));
      await pumpEventQueue();

      refreshTokenEventController.add(TokenExpired());
      await pumpEventQueue();

      expect(states, [
        isEverState(),
        isEverState(
          isAuthenticated: true,
          currentUser: user,
        ),
        isEverState(),
      ]);
    });

    test('refreshes session and updates state', () async {
      final user = User(
        id: '1',
        username: 'testuser',
        createdAt: DateTime.now(),
      );
      
      await presenter.refreshSession();
      await pumpEventQueue();
      refreshTokenEventController.add(OperationInProgress('refresh_token'));
      await pumpEventQueue();
      refreshTokenEventController.add(TokenObtained('new_token', DateTime.now().add(Duration(hours: 1))));
      await pumpEventQueue();
      getCurrentUserEventController.add(CurrentUserRetrieved(user));
      await pumpEventQueue();

      expect(states.length, 3);
      expect(states[0], isEverState());
      expect(states[1], isEverState(isLoading: true));
      expect(states[2], isEverState(
        isLoading: false,
        currentUser: user,
        isAuthenticated: true,
      ));
    });
  });

  group('logout', () {
    test('updates state during logout flow', () async {
      final user = User(
        id: '1',
        username: 'testuser',
        createdAt: DateTime.now(),
      );
      getCurrentUserEventController.add(CurrentUserRetrieved(user));
      await pumpEventQueue();

      await presenter.logout();
      await pumpEventQueue();
      signOutEventController.add(OperationInProgress('sign_out'));
      await pumpEventQueue();
      signOutEventController.add(UserLoggedOut());
      await pumpEventQueue();

      expect(states, [
        isEverState(),
        isEverState(
          isAuthenticated: true,
          currentUser: user,
        ),
        isEverState(
          isAuthenticated: true,
          currentUser: user,
          isLoading: true,
        ),
        isEverState(),
      ]);
    });
  });

  group('error handling', () {
    test('clears error on new operation', () async {
      await presenter.login('secret123');
      await pumpEventQueue();
      loginEventController.add(OperationInProgress('login'));
      await pumpEventQueue();
      loginEventController.add(OperationFailure('login', 'Invalid credentials'));
      await pumpEventQueue();

      await presenter.login('secret456');
      await pumpEventQueue();

      expect(states.length, 4);
      expect(states[0], isEverState());
      expect(states[1], isEverState(isLoading: true));
      expect(states[2], isEverState(error: 'Invalid credentials'));
      expect(states[3], isEverState(isLoading: true, error: null));
    });
  });

  group('note operations', () {
    late User testUser;

    setUp(() async {
      // Authenticate user first
      testUser = User(
        id: '1',
        username: 'testuser',
        createdAt: DateTime.now(),
      );
      getCurrentUserEventController.add(CurrentUserRetrieved(testUser));
      await pumpEventQueue();
    });

    test('getNote executes get note use case with correct parameters', () async {
      // Arrange
      final noteId = '123';
      final noteController = StreamController<note_entity.Note>();
      when(mockGetNoteUseCase.note).thenAnswer((_) => noteController.stream);
      
      // Act
      final noteStream = presenter.getNote(noteId);
      await pumpEventQueue();
      
      // Assert
      verify(mockGetNoteUseCase.execute(argThat(
        isA<GetNoteParams>().having((p) => p.id, 'id', noteId),
      ))).called(1);

      // Complete the stream to avoid timeout
      final testNote = note_entity.Note(
        id: noteId,
        content: 'test',
        userId: testUser.id,
        createdAt: DateTime.now(),
        processingStatus: note_entity.ProcessingStatus.pending,
      );
      
      noteController.add(testNote);
      await pumpEventQueue();
      
      // Wait for the first note from the stream
      final receivedNote = await noteStream.first;
      expect(receivedNote, equals(testNote));
      
      // Cleanup
      await noteController.close();
    });

    test('getNote handles errors correctly', () async {
      // Arrange
      final noteId = '123';
      final error = 'Note not found';
      final noteController = StreamController<note_entity.Note>();
      when(mockGetNoteUseCase.note).thenAnswer((_) => noteController.stream);
      
      // Act
      final noteStream = presenter.getNote(noteId);
      getNoteEventController.add(OperationInProgress('get_note'));
      await pumpEventQueue();
      
      // Add error to both streams
      getNoteEventController.add(OperationFailure('get_note', error));
      noteController.addError(error);
      await pumpEventQueue();
      
      // Assert states
      expect(states.length, 4); // Initial + Auth + Loading + Error
      expect(states[0], isEverState());
      expect(states[1], isEverState(isAuthenticated: true, currentUser: testUser));
      expect(states[2], isEverState(isAuthenticated: true, currentUser: testUser, isLoading: true));
      expect(states[3], isEverState(isAuthenticated: true, currentUser: testUser, isLoading: false, error: error));
      
      // Assert stream error
      expect(() => noteStream.first, throwsA(equals(error)));
      
      // Cleanup
      await noteController.close();
    });
  });

  group('task operations', () {
    late User testUser;

    setUp(() async {
      // Authenticate user first
      testUser = User(
        id: '1',
        username: 'testuser',
        createdAt: DateTime.now(),
      );
      getCurrentUserEventController.add(CurrentUserRetrieved(testUser));
      await pumpEventQueue();
    });

    test('createTask executes create task use case with correct parameters', () async {
      // Arrange
      final content = 'Test Task';

      // Act
      await presenter.createTask(content: content);
      await pumpEventQueue();

      // Assert
      verify(mockCreateTaskUseCase.execute(argThat(
        isA<CreateTaskParams>()
          .having((p) => p.content, 'content', content)
          .having((p) => p.status, 'status', TaskStatus.todo)
          .having((p) => p.priority, 'priority', TaskPriority.medium),
      ))).called(1);
    });

    test('updateTask executes update task use case with correct parameters', () async {
      // Arrange
      final taskId = '123';
      final content = 'Updated Task';
      //final status = 'done';

      // Act
      await presenter.updateTask(taskId, content: content, status: TaskStatus.done);
      await pumpEventQueue();

      // Assert
      verify(mockUpdateTaskUseCase.execute(argThat(
        isA<UpdateTaskParams>()
          .having((p) => p.taskId, 'taskId', taskId)
          .having((p) => p.content, 'content', content)
          .having((p) => p.status, 'status', TaskStatus.done),
      ))).called(1);
    });

    test('deleteTask executes delete task use case with correct parameters', () async {
      // Arrange
      final taskId = '123';

      // Act
      await presenter.deleteTask(taskId);
      await pumpEventQueue();

      // Assert
      verify(mockDeleteTaskUseCase.execute(argThat(
        isA<DeleteTaskParams>().having((p) => p.taskId, 'taskId', taskId),
      ))).called(1);
    });

    test('viewTask executes get task use case with correct parameters', () async {
      // Arrange
      final taskId = '123';

      // Act
      await presenter.viewTask(taskId);
      await pumpEventQueue();

      // Assert
      verify(mockGetTaskUseCase.execute(argThat(
        isA<GetTaskParams>().having((p) => p.id, 'id', taskId),
      ))).called(1);
    });

    test('listTasks executes list tasks use case', () async {
      // Act
      await presenter.listTasks();
      await pumpEventQueue();

      // Assert
      verify(mockListTasksUseCase.execute(any)).called(1);
    });

    test('handles task operation errors correctly', () async {
      // Arrange
      final error = 'Failed to create task';

      // Act
      await presenter.createTask(content: 'Test Task');
      createTaskEventController.add(OperationInProgress('create_task'));
      await pumpEventQueue();
      createTaskEventController.add(OperationFailure('create_task', error));
      await pumpEventQueue();

      // Assert
      expect(states.length, 4); // Initial + Auth + Loading + Error
      expect(states[0], isEverState());
      expect(states[1], isEverState(isAuthenticated: true, currentUser: testUser));
      expect(states[2], isEverState(isAuthenticated: true, currentUser: testUser, isLoading: true));
      expect(states[3], isEverState(isAuthenticated: true, currentUser: testUser, isLoading: false, error: error));
    });
  });
} 