import 'dart:async';

import 'package:rxdart/rxdart.dart';
import '../../domain/core/events.dart';
import '../../domain/core/user_events.dart';
import '../../domain/presenter/ever_presenter.dart';
import '../../domain/usecases/user/get_current_user_usecase.dart';
import '../../domain/usecases/user/login_usecase.dart';
import '../../domain/usecases/user/refresh_token_usecase.dart';
import '../../domain/usecases/user/register_usecase.dart';
import '../../domain/usecases/user/sign_out_usecase.dart';

/// Flutter implementation of the Ever presenter
class FlutterEverPresenter implements EverPresenter {
  final RegisterUseCase _registerUseCase;
  final LoginUseCase _loginUseCase;
  final SignOutUseCase _signOutUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;

  final _stateController = BehaviorSubject<EverState>.seeded(EverState.initial());
  final List<StreamSubscription> _subscriptions = [];

  FlutterEverPresenter({
    required RegisterUseCase registerUseCase,
    required LoginUseCase loginUseCase,
    required SignOutUseCase signOutUseCase,
    required RefreshTokenUseCase refreshTokenUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
  })  : _registerUseCase = registerUseCase,
        _loginUseCase = loginUseCase,
        _signOutUseCase = signOutUseCase,
        _refreshTokenUseCase = refreshTokenUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase {
    // Subscribe to all use case events
    _subscriptions.addAll([
      _registerUseCase.events.listen(_handleUserEvents),
      _loginUseCase.events.listen(_handleUserEvents),
      _signOutUseCase.events.listen(_handleUserEvents),
      _refreshTokenUseCase.events.listen(_handleTokenEvents),
      _getCurrentUserUseCase.events.listen(_handleUserEvents),
    ]);
  }

  @override
  Stream<EverState> get state => _stateController.stream;

  void _updateState(EverState newState) {
    // Only emit state if it's different from the current state
    if (_stateController.value != newState) {
      _stateController.add(newState);
    }
  }

  @override
  Future<void> initialize() async {
    // Get current user on initialization
    await getCurrentUser();
  }

  void _handleUserEvents(DomainEvent event) {
    print('🔍 [Debug] Presenter handling event: ${event.runtimeType}');
    
    if (event is CurrentUserRetrieved) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          currentUser: event.user,
          isAuthenticated: event.user != null,
          error: null,
        ),
      );
    } else if (event is UserRegistered) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          currentUser: event.user,
          isAuthenticated: true,
          error: null,
        ),
      );
    } else if (event is OperationFailure) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          error: event.error,
        ),
      );
    } else if (event is OperationInProgress) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: true,
          error: null,
        ),
      );
    } else if (event is UserLoggedOut) {
      _updateState(
        EverState.initial(),
      );
    }
  }

  void _handleTokenEvents(DomainEvent event) {
    if (event is TokenExpired) {
      _updateState(
        EverState.initial(),
      );
    } else if (event is TokenObtained || event is TokenRefreshed) {
      // Keep loading state true while getting user
      _updateState(
        _stateController.value.copyWith(
          isLoading: true,
          error: null,
        ),
      );
      // Get current user after token is obtained
      _getCurrentUserUseCase.execute();
    }
  }

  @override
  Future<void> register(String username) async {
    _updateState(EverState.initial().copyWith(isLoading: true));
    _registerUseCase.execute(RegisterParams(username: username));
  }

  @override
  Future<void> login(String userSecret) async {
    _updateState(EverState.initial().copyWith(isLoading: true));
    _loginUseCase.execute(LoginParams(userSecret: userSecret));
  }

  @override
  Future<void> logout() async {
    _updateState(_stateController.value.copyWith(isLoading: true));
    _signOutUseCase.execute();
  }

  @override
  Future<void> refreshSession() async {
    _updateState(EverState.initial().copyWith(isLoading: true));
    _refreshTokenUseCase.execute();
  }

  @override
  Future<void> getCurrentUser() async {
    _updateState(EverState.initial().copyWith(isLoading: true));
    _getCurrentUserUseCase.execute();
  }

  @override
  Future<void> createNote(String title, String content) async {
    // TODO: Implement when note usecases are ready
    throw UnimplementedError();
  }

  @override
  Future<void> updateNote(String noteId, {String? title, String? content}) async {
    // TODO: Implement when note usecases are ready
    throw UnimplementedError();
  }

  @override
  Future<void> deleteNote(String noteId) async {
    // TODO: Implement when note usecases are ready
    throw UnimplementedError();
  }

  @override
  Future<void> getNotes() async {
    // TODO: Implement when note usecases are ready
    throw UnimplementedError();
  }

  @override
  Future<void> createTask(String title, DateTime dueDate) async {
    // TODO: Implement when task usecases are ready
    throw UnimplementedError();
  }

  @override
  Future<void> updateTask(String taskId, {String? title, DateTime? dueDate, bool? completed}) async {
    // TODO: Implement when task usecases are ready
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTask(String taskId) async {
    // TODO: Implement when task usecases are ready
    throw UnimplementedError();
  }

  @override
  Future<void> getTasks() async {
    // TODO: Implement when task usecases are ready
    throw UnimplementedError();
  }

  @override
  Future<void> refresh() async {
    await getCurrentUser();
    // TODO: Add refresh for notes and tasks when implemented
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _stateController.close();
  }

  // Cache for user secret
  String? _cachedUserSecret;

  void _cacheUserSecret(String secret) {
    _cachedUserSecret = secret;
  }

  void _clearCachedUserSecret() {
    _cachedUserSecret = null;
  }

  @override
  Future<String?> getCachedUserSecret() async {
    return _cachedUserSecret;
  }
} 