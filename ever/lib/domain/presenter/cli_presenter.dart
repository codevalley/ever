import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../core/events.dart';
import '../core/user_events.dart';
import '../usecases/user/get_current_user_usecase.dart';
import '../usecases/user/login_usecase.dart';
import '../usecases/user/refresh_token_usecase.dart';
import '../usecases/user/register_usecase.dart';
import '../usecases/user/sign_out_usecase.dart';
import 'ever_presenter.dart';

/// CLI implementation of the Ever presenter
class CliPresenter implements EverPresenter {
  final RegisterUseCase _registerUseCase;
  final LoginUseCase _loginUseCase;
  final SignOutUseCase _signOutUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;

  final _stateController = BehaviorSubject<EverState>.seeded(EverState.initial());
  final List<StreamSubscription> _subscriptions = [];

  CliPresenter({
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
    // Check if we have both token and user secret
    final token = await _loginUseCase.getCachedToken();
    final userSecret = await getCachedUserSecret();
    
    if (token != null && userSecret != null) {
      // We have credentials, try to get current user
      await getCurrentUser();
    } else {
      // No credentials, start in initial state
      _updateState(EverState.initial());
    }
  }

  void _handleUserEvents(DomainEvent event) {
    print('🔍 [Debug] CLI Presenter handling event: ${event.runtimeType}');
    
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
      print('🔍 [Debug] CLI Presenter handling UserRegistered event');
      // Cache the user secret when registering
      _cacheUserSecret(event.userSecret);
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          currentUser: event.user,
          isAuthenticated: true,
          error: null,
        ),
      );
      // After registration, try to obtain token and get user info
      login(event.userSecret);
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
      // Clear cached secret on logout
      _clearCachedUserSecret();
      _updateState(
        EverState.initial(),
      );
    }
  }

  void _handleTokenEvents(DomainEvent event) {
    print('🔍 [Debug] CLI Presenter handling token event: ${event.runtimeType}');
    if (event is TokenExpired) {
      _updateState(
        EverState.initial(),
      );
    } else if (event is TokenObtained || event is TokenRefreshed) {
      print('🔍 [Debug] Token obtained, getting current user');
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
    print('🔍 [Debug] Starting login process');
    _updateState(EverState.initial().copyWith(isLoading: true));
    
    try {
      // First obtain token
      print('🔍 [Debug] Obtaining token');
      _loginUseCase.execute(LoginParams(userSecret: userSecret));
      
      // Wait for token events to be processed
      var tokenObtained = false;
      var attempts = 0;
      while (!tokenObtained && attempts < 3) {
        attempts++;
        try {
          await for (final event in _loginUseCase.events.timeout(Duration(seconds: 10))) {
            print('🔍 [Debug] Token event: ${event.runtimeType}');
            if (event is TokenObtained) {
              print('🔍 [Debug] Token obtained in login flow');
              tokenObtained = true;
              break;
            } else if (event is OperationFailure) {
              throw Exception(event.error);
            }
          }
        } catch (e) {
          print('⚠️ [Warning] Token attempt $attempts failed: ${e.toString()}');
          if (attempts >= 3) {
            throw Exception('Failed to obtain token after multiple attempts');
          }
          await Future.delayed(Duration(milliseconds: 100));
        }
      }
      
      if (!tokenObtained) {
        throw Exception('Failed to obtain token');
      }

      // Now get current user
      print('🔍 [Debug] Getting current user info');
      print('🔍 [Debug] Executing getCurrentUserUseCase');
      _getCurrentUserUseCase.execute();
      
      // Create a completer to handle the user info retrieval
      final completer = Completer<void>();
      StreamSubscription? subscription;
      
      subscription = _getCurrentUserUseCase.events.listen(
        (event) {
          print('🔍 [Debug] User info event: ${event.runtimeType}');
          if (event is CurrentUserRetrieved) {
            print('🔍 [Debug] User info retrieved successfully');
            completer.complete();
          } else if (event is OperationFailure) {
            print('❌ [Error] Failed to get user info: ${event.error}');
            completer.completeError(Exception(event.error));
          }
        },
        onError: (error) {
          print('❌ [Error] User info stream error: $error');
          completer.completeError(error);
        },
        onDone: () {
          print('🔍 [Debug] User info stream completed');
          if (!completer.isCompleted) {
            completer.completeError(Exception('User info stream completed without result'));
          }
        },
      );

      // Wait for completion with timeout
      try {
        await completer.future.timeout(Duration(seconds: 10));
      } catch (e) {
        print('❌ [Error] User info timeout: $e');
        throw Exception('Failed to get user info: $e');
      } finally {
        await subscription?.cancel();
      }
    } catch (e) {
      print('❌ [Error] Login failed: ${e.toString()}');
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
    }
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
    throw UnimplementedError();
  }

  @override
  Future<void> updateNote(String noteId, {String? title, String? content}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteNote(String noteId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> getNotes() async {
    throw UnimplementedError();
  }

  @override
  Future<void> createTask(String title, DateTime dueDate) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateTask(String taskId, {String? title, DateTime? dueDate, bool? completed}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTask(String taskId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> getTasks() async {
    throw UnimplementedError();
  }

  @override
  Future<void> refresh() async {
    await getCurrentUser();
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