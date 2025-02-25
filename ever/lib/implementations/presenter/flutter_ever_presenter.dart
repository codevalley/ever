import 'dart:async';

import 'package:rxdart/rxdart.dart';
import '../../core/logging.dart';
import '../../domain/core/events.dart';
import '../../domain/events/note_events.dart';
import '../../domain/events/user_events.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/task.dart';
import '../../domain/presenter/ever_presenter.dart';
import '../../domain/usecases/note/create_note_usecase.dart';
import '../../domain/usecases/note/update_note_usecase.dart';
import '../../domain/usecases/note/delete_note_usecase.dart';
import '../../domain/usecases/note/get_note_usecase.dart';
import '../../domain/usecases/note/list_notes_usecase.dart';
import '../../domain/usecases/user/get_current_user_usecase.dart';
import '../../domain/usecases/user/login_usecase.dart';
import '../../domain/usecases/user/refresh_token_usecase.dart';
import '../../domain/usecases/user/register_usecase.dart';
import '../../domain/usecases/user/sign_out_usecase.dart';
import '../../domain/usecases/task/create_task_usecase.dart';
import '../../domain/usecases/task/update_task_usecase.dart';
import '../../domain/usecases/task/delete_task_usecase.dart';
import '../../domain/usecases/task/list_tasks_usecase.dart';
import '../../domain/usecases/task/get_task_usecase.dart';

/// Flutter implementation of the Ever presenter
class FlutterEverPresenter implements EverPresenter {
  final RegisterUseCase _registerUseCase;
  final LoginUseCase _loginUseCase;
  final SignOutUseCase _signOutUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;

  final CreateNoteUseCase _createNoteUseCase;
  final UpdateNoteUseCase _updateNoteUseCase;
  final DeleteNoteUseCase _deleteNoteUseCase;
  final GetNoteUseCase _getNoteUseCase;
  final ListNotesUseCase _listNotesUseCase;

  final CreateTaskUseCase _createTaskUseCase;
  final UpdateTaskUseCase _updateTaskUseCase;
  final DeleteTaskUseCase _deleteTaskUseCase;
  final ListTasksUseCase _listTasksUseCase;
  final GetTaskUseCase _getTaskUseCase;

  final _stateController = BehaviorSubject<EverState>.seeded(EverState.initial());
  final _events = BehaviorSubject<DomainEvent>();
  final List<StreamSubscription> _subscriptions = [];

  FlutterEverPresenter({
    required RegisterUseCase registerUseCase,
    required LoginUseCase loginUseCase,
    required SignOutUseCase signOutUseCase,
    required RefreshTokenUseCase refreshTokenUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required CreateNoteUseCase createNoteUseCase,
    required UpdateNoteUseCase updateNoteUseCase,
    required DeleteNoteUseCase deleteNoteUseCase,
    required GetNoteUseCase getNoteUseCase,
    required ListNotesUseCase listNotesUseCase,
    required CreateTaskUseCase createTaskUseCase,
    required UpdateTaskUseCase updateTaskUseCase,
    required DeleteTaskUseCase deleteTaskUseCase,
    required ListTasksUseCase listTasksUseCase,
    required GetTaskUseCase getTaskUseCase,
  })  : _registerUseCase = registerUseCase,
        _loginUseCase = loginUseCase,
        _signOutUseCase = signOutUseCase,
        _refreshTokenUseCase = refreshTokenUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        _createNoteUseCase = createNoteUseCase,
        _updateNoteUseCase = updateNoteUseCase,
        _deleteNoteUseCase = deleteNoteUseCase,
        _getNoteUseCase = getNoteUseCase,
        _listNotesUseCase = listNotesUseCase,
        _createTaskUseCase = createTaskUseCase,
        _updateTaskUseCase = updateTaskUseCase,
        _deleteTaskUseCase = deleteTaskUseCase,
        _listTasksUseCase = listTasksUseCase,
        _getTaskUseCase = getTaskUseCase {
    
    // Subscribe to all use case events and merge them into a single stream
    _subscriptions.addAll([
      _registerUseCase.events.listen(_events.add),
      _loginUseCase.events.listen(_events.add),
      _signOutUseCase.events.listen(_events.add),
      _refreshTokenUseCase.events.listen(_events.add),
      _getCurrentUserUseCase.events.listen(_events.add),
      _createNoteUseCase.events.listen(_events.add),
      _updateNoteUseCase.events.listen(_events.add),
      _deleteNoteUseCase.events.listen(_events.add),
      _getNoteUseCase.events.listen(_events.add),
      _listNotesUseCase.events.listen(_events.add),
      _createTaskUseCase.events.listen(_events.add),
      _updateTaskUseCase.events.listen(_events.add),
      _deleteTaskUseCase.events.listen(_events.add),
      _listTasksUseCase.events.listen(_events.add),
      _getTaskUseCase.events.listen(_events.add),
    ]);

    // Subscribe to the merged events stream to update state
    _subscriptions.add(_events.stream.listen((event) {
      if (event is CurrentUserRetrieved ||
          event is UserRegistered ||
          event is UserLoggedOut) {
        _handleUserEvents(event);
      } else if (event is TokenObtained ||
                 event is TokenRefreshed ||
                 event is TokenExpired) {
        _handleTokenEvents(event);
      } else if (event is NoteCreated ||
                 event is NoteUpdated ||
                 event is NoteDeleted ||
                 event is NotesRetrieved) {
        _handleNoteEvents(event);
      } else if (event is OperationInProgress ||
                 event is OperationSuccess ||
                 event is OperationFailure) {
        // Handle generic operation events
        if (event is OperationInProgress) {
          // Always clear error when starting a new operation
          _updateState(
            _stateController.value.copyWith(
              isLoading: true,
              error: null,
            ),
          );
        } else if (event is OperationSuccess) {
          _updateState(
            _stateController.value.copyWith(
              isLoading: false,
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
        }
      }
    }));
  }

  @override
  Stream<EverState> get state => _stateController.stream;

  @override
  Stream<DomainEvent> get events => _events.stream;

  void _updateState(EverState newState) {
    // Only emit state if it's different from the current state
    if (_stateController.value != newState) {
      dprint('Updating state: isLoading=${newState.isLoading}, error=${newState.error}, isAuthenticated=${newState.isAuthenticated}');
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
    dprint('Flutter Presenter handling event: ${event.runtimeType}');
    
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
      dprint('Flutter Presenter handling UserRegistered event');
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
    } else if (event is UserLoggedOut) {
      _clearCachedUserSecret();
      _updateState(
        EverState.initial(),
      );
    }
  }

  void _handleTokenEvents(DomainEvent event) {
    dprint('Flutter Presenter handling token event: ${event.runtimeType}');
    if (event is TokenExpired) {
      _updateState(
        EverState.initial(),
      );
    } else if (event is TokenObtained || event is TokenRefreshed) {
      dprint('Token obtained, getting current user');
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

  void _handleNoteEvents(DomainEvent event) {
    dprint('Flutter Presenter handling note event: ${event.runtimeType}');
    
    if (event is NoteCreated) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          notes: [..._stateController.value.notes, event.note],
          error: null,
        ),
      );
    } else if (event is NoteUpdated) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          notes: _stateController.value.notes.map(
            (note) => note.id == event.note.id ? event.note : note
          ).toList(),
          error: null,
        ),
      );
    } else if (event is NoteDeleted) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          notes: _stateController.value.notes.where(
            (note) => note.id != event.noteId
          ).toList(),
          error: null,
        ),
      );
    } else if (event is NotesRetrieved) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          notes: event.notes,
          error: null,
        ),
      );
    }
  }

  @override
  Future<void> register(String username) async {
    _updateState(EverState.initial().copyWith(isLoading: true));
    _registerUseCase.execute(RegisterParams(username: username));
  }

  @override
  Future<void> login(String userSecret) async {
    try {
      dprint('Starting login attempt with userSecret: $userSecret');
      // Reset state completely and set loading
      _updateState(EverState.initial().copyWith(
        isLoading: true,
      ));

      // Execute login
      _loginUseCase.execute(LoginParams(userSecret: userSecret));
    } catch (e) {
      eprint('Login failed: ${e.toString()}');
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
      rethrow;
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
  Future<void> createNote(String content) async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to create notes');
    }
    
    _updateState(_stateController.value.copyWith(isLoading: true));
    
    try {
      await _createNoteUseCase.execute(CreateNoteParams(
        content: content,
        userId: _stateController.value.currentUser!.id,
      ));
    } catch (e) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> updateNote(String noteId, {String? title, String? content}) async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to update notes');
    }
    
    _updateState(_stateController.value.copyWith(isLoading: true));
    
    try {
      await _updateNoteUseCase.execute(UpdateNoteParams(
        noteId: noteId,
        content: content,
      ));
    } catch (e) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
    }
  }

  @override
  Future<void> deleteNote(String noteId) async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to delete notes');
    }
    
    _updateState(_stateController.value.copyWith(isLoading: true));
    
    try {
      await _deleteNoteUseCase.execute(DeleteNoteParams(noteId: noteId));
    } catch (e) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
    }
  }

  @override
  Stream<Note> getNote(String noteId) {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to get notes');
    }
    
    _getNoteUseCase.execute(GetNoteParams(id: noteId));
    return _getNoteUseCase.note;
  }

  @override
  Future<List<Note>> listNotes({bool includeArchived = false}) async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to list notes');
    }
    
    _updateState(_stateController.value.copyWith(isLoading: true));
    
    try {
      await _listNotesUseCase.execute(ListNotesParams(
        filters: {
          'user_id': _stateController.value.currentUser!.id,
          if (!includeArchived) 'archived': false,
        },
      ));
      return _stateController.value.notes;
    } catch (e) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          error: e.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> createTask({
    required String content,
    TaskStatus? status = TaskStatus.todo,
    TaskPriority? priority = TaskPriority.medium,
    DateTime? dueDate,
    List<String>? tags,
    String? parentId,
    String? topicId,
  }) async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to create tasks');
    }
    
    _createTaskUseCase.execute(CreateTaskParams(
      content: content,
      status: status ?? TaskStatus.todo,
      priority: priority ?? TaskPriority.medium,
      tags: tags,
      parentId: parentId,
      topicId: topicId,
    ));
  }

  @override
  Future<void> updateTask(String taskId, {
    String? content,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    List<String>? tags,
    String? parentId,
    String? topicId,
  }) async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to update tasks');
    }
    
    _updateTaskUseCase.execute(UpdateTaskParams(
      taskId: taskId,
      content: content,
      status: status,
      priority: priority,
      tags: tags,
      parentId: parentId,
      topicId: topicId,
    ));
  }

  @override
  Future<void> deleteTask(String taskId) async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to delete tasks');
    }
    
    _deleteTaskUseCase.execute(DeleteTaskParams(taskId: taskId));
  }

  @override
  Future<void> viewTask(String taskId) async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to view tasks');
    }
    
    _getTaskUseCase.execute(GetTaskParams(id: taskId));
  }

  @override
  Future<void> listTasks() async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to list tasks');
    }
    
    _listTasksUseCase.execute(ListTasksParams());
  }

  @override
  Future<void> refresh() async {
    try {
      await getCurrentUser();
      await listNotes();
      await listTasks();
    } catch (e) {
      // Ignore errors during refresh
    }
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