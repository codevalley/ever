import 'dart:async';

import 'package:ever/domain/core/events.dart';
import 'package:ever/domain/events/user_events.dart';
import 'package:ever/domain/entities/user.dart';
import 'package:ever/domain/presenter/ever_presenter.dart';
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
])
void main() {
  late MockRegisterUseCase mockRegisterUseCase;
  late MockLoginUseCase mockLoginUseCase;
  late MockSignOutUseCase mockSignOutUseCase;
  late MockRefreshTokenUseCase mockRefreshTokenUseCase;
  late MockGetCurrentUserUseCase mockGetCurrentUserUseCase;
  late FlutterEverPresenter presenter;
  late List<EverState> states;
  late StreamController<DomainEvent> registerEventController;
  late StreamController<DomainEvent> loginEventController;
  late StreamController<DomainEvent> signOutEventController;
  late StreamController<DomainEvent> refreshTokenEventController;
  late StreamController<DomainEvent> getCurrentUserEventController;

  setUp(() async {
    mockRegisterUseCase = MockRegisterUseCase();
    mockLoginUseCase = MockLoginUseCase();
    mockSignOutUseCase = MockSignOutUseCase();
    mockRefreshTokenUseCase = MockRefreshTokenUseCase();
    mockGetCurrentUserUseCase = MockGetCurrentUserUseCase();

    registerEventController = StreamController<DomainEvent>.broadcast();
    loginEventController = StreamController<DomainEvent>.broadcast();
    signOutEventController = StreamController<DomainEvent>.broadcast();
    refreshTokenEventController = StreamController<DomainEvent>.broadcast();
    getCurrentUserEventController = StreamController<DomainEvent>.broadcast();

    when(mockRegisterUseCase.events).thenAnswer((_) => registerEventController.stream);
    when(mockLoginUseCase.events).thenAnswer((_) => loginEventController.stream);
    when(mockSignOutUseCase.events).thenAnswer((_) => signOutEventController.stream);
    when(mockRefreshTokenUseCase.events).thenAnswer((_) => refreshTokenEventController.stream);
    when(mockGetCurrentUserUseCase.events).thenAnswer((_) => getCurrentUserEventController.stream);

    presenter = FlutterEverPresenter(
      registerUseCase: mockRegisterUseCase,
      loginUseCase: mockLoginUseCase,
      signOutUseCase: mockSignOutUseCase,
      refreshTokenUseCase: mockRefreshTokenUseCase,
      getCurrentUserUseCase: mockGetCurrentUserUseCase,
    );

    states = [];
    presenter.state.listen(states.add);
    await Future.delayed(Duration.zero);
  });

  tearDown(() async {
    await presenter.dispose();
    await registerEventController.close();
    await loginEventController.close();
    await signOutEventController.close();
    await refreshTokenEventController.close();
    await getCurrentUserEventController.close();
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
    test('executes login use case with correct parameters', () async {
      await presenter.login('secret123');
      await pumpEventQueue();

      verify(mockLoginUseCase.execute(argThat(
        isA<LoginParams>().having((p) => p.userSecret, 'userSecret', 'secret123'),
      ))).called(1);
    });

    test('updates state during login flow', () async {
      final user = User(
        id: '1',
        username: 'testuser',
        createdAt: DateTime.now(),
      );
      
      await presenter.login('secret123');
      await pumpEventQueue();
      loginEventController.add(OperationInProgress('login'));
      await pumpEventQueue();
      getCurrentUserEventController.add(CurrentUserRetrieved(user));
      await pumpEventQueue();

      expect(states, [
        isEverState(),
        isEverState(isLoading: true),
        isEverState(
          isLoading: false,
          currentUser: user,
          isAuthenticated: true,
        ),
      ]);
    });

    test('handles login failure', () async {
      await presenter.login('secret123');
      await pumpEventQueue();
      loginEventController.add(OperationInProgress('login'));
      await pumpEventQueue();
      loginEventController.add(OperationFailure('login', 'Invalid credentials'));
      await pumpEventQueue();

      expect(states, [
        isEverState(),
        isEverState(isLoading: true),
        isEverState(error: 'Invalid credentials'),
      ]);
    });

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