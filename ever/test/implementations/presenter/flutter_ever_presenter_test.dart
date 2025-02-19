import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/user_events.dart';
import 'package:ever/domain/entities/user.dart';
import 'package:ever/domain/presenter/ever_presenter.dart';
import 'package:ever/domain/usecases/note/create_note_usecase.dart';
import 'package:ever/domain/usecases/note/update_note_usecase.dart';
import 'package:ever/domain/usecases/note/delete_note_usecase.dart';
import 'package:ever/domain/usecases/note/list_notes_usecase.dart';
import 'package:ever/domain/usecases/user/get_current_user_usecase.dart';
import 'package:ever/domain/usecases/user/login_usecase.dart';
import 'package:ever/domain/usecases/user/refresh_token_usecase.dart';
import 'package:ever/domain/usecases/user/register_usecase.dart';
import 'package:ever/domain/usecases/user/sign_out_usecase.dart';
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

    registerEventController = StreamController<DomainEvent>();
    loginEventController = StreamController<DomainEvent>();
    signOutEventController = StreamController<DomainEvent>();
    refreshTokenEventController = StreamController<DomainEvent>();
    getCurrentUserEventController = StreamController<DomainEvent>();
    createNoteEventController = StreamController<DomainEvent>();
    updateNoteEventController = StreamController<DomainEvent>();
    deleteNoteEventController = StreamController<DomainEvent>();
    listNotesEventController = StreamController<DomainEvent>();

    when(mockRegisterUseCase.events).thenAnswer((_) => registerEventController.stream);
    when(mockLoginUseCase.events).thenAnswer((_) => loginEventController.stream);
    when(mockSignOutUseCase.events).thenAnswer((_) => signOutEventController.stream);
    when(mockRefreshTokenUseCase.events).thenAnswer((_) => refreshTokenEventController.stream);
    when(mockGetCurrentUserUseCase.events).thenAnswer((_) => getCurrentUserEventController.stream);
    when(mockCreateNoteUseCase.events).thenAnswer((_) => createNoteEventController.stream);
    when(mockUpdateNoteUseCase.events).thenAnswer((_) => updateNoteEventController.stream);
    when(mockDeleteNoteUseCase.events).thenAnswer((_) => deleteNoteEventController.stream);
    when(mockListNotesUseCase.events).thenAnswer((_) => listNotesEventController.stream);

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
} 