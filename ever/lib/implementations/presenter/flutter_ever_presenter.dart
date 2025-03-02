import 'dart:async';

import 'package:rxdart/rxdart.dart';
import '../../core/logging.dart';
import '../../domain/core/events.dart';
import '../../domain/events/note_events.dart';
import '../../domain/events/task_events.dart';
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

/// Exception thrown when attempting an operation that requires authentication
class NotAuthenticatedException implements Exception {
  final String message;
  NotAuthenticatedException(this.message);
  @override
  String toString() => 'NotAuthenticatedException: $message';
}

/// Exception thrown when a network operation fails
class NetworkOperationException implements Exception {
  final String operation;
  final String message;
  NetworkOperationException(this.operation, this.message);
  @override
  String toString() => 'NetworkOperationException[$operation]: $message';
}

/// Flutter implementation of the Ever presenter
class FlutterEverPresenter implements EverPresenter {

  // Use cases
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

  // State management
  final _stateController = BehaviorSubject<EverState>.seeded(EverState.initial());
  late final BehaviorSubject<EverState> _publicStateController;
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
    
    // Initialize public state controller with debounce
    _publicStateController = BehaviorSubject<EverState>.seeded(EverState.initial());
    _setupStateDebouncer();
    
    // Subscribe to all use case events and merge them into a single stream
    _addSubscription(_registerUseCase.events.listen(_events.add));
    _addSubscription(_loginUseCase.events.listen(_events.add));
    _addSubscription(_signOutUseCase.events.listen(_events.add));
    _addSubscription(_refreshTokenUseCase.events.listen(_events.add));
    _addSubscription(_getCurrentUserUseCase.events.listen(_events.add));
    _addSubscription(_createNoteUseCase.events.listen(_events.add));
    _addSubscription(_updateNoteUseCase.events.listen(_events.add));
    _addSubscription(_deleteNoteUseCase.events.listen(_events.add));
    _addSubscription(_getNoteUseCase.events.listen(_events.add));
    _addSubscription(_listNotesUseCase.events.listen(_events.add));
    _addSubscription(_createTaskUseCase.events.listen(_events.add));
    _addSubscription(_updateTaskUseCase.events.listen(_events.add));
    _addSubscription(_deleteTaskUseCase.events.listen(_events.add));
    _addSubscription(_listTasksUseCase.events.listen(_events.add));
    _addSubscription(_getTaskUseCase.events.listen(_events.add));

    // Set up event handlers map for more declarative handling
    final eventHandlers = <Type, Function(DomainEvent)>{
      // User events
      CurrentUserRetrieved: (event) => _handleCurrentUserRetrieved(event as CurrentUserRetrieved),
      UserRegistered: (event) => _handleUserRegistered(event as UserRegistered),
      UserLoggedOut: (event) => _handleUserLoggedOut(event as UserLoggedOut),
      
      // Token events
      TokenObtained: (event) => _handleTokenObtained(event as TokenObtained),
      TokenRefreshed: (event) => _handleTokenRefreshed(event as TokenRefreshed),
      TokenExpired: (event) => _handleTokenExpired(event as TokenExpired),
      
      // Note events
      NoteCreated: (event) => _handleNoteCreated(event as NoteCreated),
      NoteUpdated: (event) => _handleNoteUpdated(event as NoteUpdated),
      NoteDeleted: (event) => _handleNoteDeleted(event as NoteDeleted),
      NotesRetrieved: (event) => _handleNotesRetrieved(event as NotesRetrieved),
      
      // Task events
      TaskCreated: (event) => _handleTaskCreated(event as TaskCreated),
      TaskUpdated: (event) => _handleTaskUpdated(event as TaskUpdated),
      TaskDeleted: (event) => _handleTaskDeleted(event as TaskDeleted),
      TasksRetrieved: (event) => _handleTasksRetrieved(event as TasksRetrieved),
      TaskRetrieved: (event) => _handleTaskRetrieved(event as TaskRetrieved),
      
      // Operation events
      OperationInProgress: (event) => _handleOperationInProgress(event as OperationInProgress),
      OperationSuccess: (event) => _handleOperationSuccess(event as OperationSuccess),
      OperationFailure: (event) => _handleOperationFailure(event as OperationFailure),
    };

    // Subscribe to the merged events stream and delegate to appropriate handler
    _addSubscription(_events.stream.listen((event) {
      final handler = eventHandlers[event.runtimeType];
      if (handler != null) {
        handler(event);
      } else {
        dprint('Unhandled event type: ${event.runtimeType}');
      }
    }));
  }
  
  // Helper for managing subscriptions
  void _addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }
  
  // Set up state debouncer to reduce UI flicker
  void _setupStateDebouncer() {
    _addSubscription(
      _stateController.stream
          .debounceTime(Duration(milliseconds: 100))
          .distinct() // Only emit distinct states
          .listen(_publicStateController.add)
    );
  }

  @override
  Stream<EverState> get state => _publicStateController.stream;

  @override
  Stream<DomainEvent> get events => _events.stream;

  /// Update state with more selective property updates
  void _updateState(EverState newState) {
    // Only emit state if it's different from the current state
    if (_stateController.value != newState) {
      final changes = <String>[];
      
      if (_stateController.value.isLoading != newState.isLoading) {
        changes.add('isLoading: ${newState.isLoading}');
      }
      
      if (_stateController.value.error != newState.error) {
        changes.add('error: ${newState.error}');
      }
      
      if (_stateController.value.isAuthenticated != newState.isAuthenticated) {
        changes.add('isAuthenticated: ${newState.isAuthenticated}');
      }
      
      if (_stateController.value.currentUser != newState.currentUser) {
        changes.add('user: ${newState.currentUser?.username}');
      }
      
      if (_stateController.value.notes.length != newState.notes.length) {
        changes.add('notes: ${newState.notes.length}');
      }
      
      if (_stateController.value.tasks.length != newState.tasks.length) {
        changes.add('tasks: ${newState.tasks.length}');
      }
      
      dprint('Updating state: ${changes.join(', ')}');
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

  // Individual event handlers for better organization

  // User event handlers
  void _handleCurrentUserRetrieved(CurrentUserRetrieved event) {
    dprint('Handling CurrentUserRetrieved: ${event.user?.username}');
    _updateState(
      _stateController.value.copyWith(
        isLoading: false,
        currentUser: event.user,
        isAuthenticated: event.user != null,
        error: null,
      ),
    );
  }

  void _handleUserRegistered(UserRegistered event) {
    dprint('Handling UserRegistered: ${event.user.username}');
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
  }

  void _handleUserLoggedOut(UserLoggedOut event) {
    dprint('Handling UserLoggedOut');
    _clearCachedUserSecret();
    _updateState(EverState.initial());
  }

  // Token event handlers
  void _handleTokenObtained(TokenObtained event) {
    dprint('Handling TokenObtained');
    _handleTokenSuccess();
  }

  void _handleTokenRefreshed(TokenRefreshed event) {
    dprint('Handling TokenRefreshed');
    _handleTokenSuccess();
  }

  void _handleTokenExpired(TokenExpired event) {
    dprint('Handling TokenExpired');
    _updateState(EverState.initial());
  }

  // Helper method for successful token events
  void _handleTokenSuccess() {
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

  // Note event handlers
  void _handleNoteCreated(NoteCreated event) {
    dprint('Handling NoteCreated: ${event.note.id}');
    _updateState(
      _stateController.value.copyWith(
        isLoading: false,
        notes: [..._stateController.value.notes, event.note],
        error: null,
      ),
    );
  }

  void _handleNoteUpdated(NoteUpdated event) {
    dprint('Handling NoteUpdated: ${event.note.id}');
    _updateState(
      _stateController.value.copyWith(
        isLoading: false,
        notes: _stateController.value.notes.map(
          (note) => note.id == event.note.id ? event.note : note
        ).toList(),
        error: null,
      ),
    );
  }

  void _handleNoteDeleted(NoteDeleted event) {
    dprint('Handling NoteDeleted: ${event.noteId}');
    _updateState(
      _stateController.value.copyWith(
        isLoading: false,
        notes: _stateController.value.notes.where(
          (note) => note.id != event.noteId
        ).toList(),
        error: null,
      ),
    );
  }

  void _handleNotesRetrieved(NotesRetrieved event) {
    dprint('Handling NotesRetrieved: ${event.notes.length} notes');
    _updateState(
      _stateController.value.copyWith(
        isLoading: false,
        notes: event.notes,
        error: null,
      ),
    );
  }

  // Task event handlers
  void _handleTaskCreated(TaskCreated event) {
    dprint('Handling TaskCreated: ${event.task.id}');
    _updateState(
      _stateController.value.copyWith(
        isLoading: false,
        tasks: [..._stateController.value.tasks, event.task],
        error: null,
      ),
    );
  }

  void _handleTaskUpdated(TaskUpdated event) {
    dprint('Handling TaskUpdated: ${event.task.id}');
    _updateState(
      _stateController.value.copyWith(
        isLoading: false,
        tasks: _stateController.value.tasks.map(
          (task) => task.id == event.task.id ? event.task : task
        ).toList(),
        error: null,
      ),
    );
  }

  void _handleTaskDeleted(TaskDeleted event) {
    dprint('Handling TaskDeleted: ${event.taskId}');
    _updateState(
      _stateController.value.copyWith(
        isLoading: false,
        tasks: _stateController.value.tasks.where(
          (task) => task.id != event.taskId
        ).toList(),
        error: null,
      ),
    );
  }

  void _handleTasksRetrieved(TasksRetrieved event) {
    dprint('Handling TasksRetrieved: ${event.tasks.length} tasks');
    _updateState(
      _stateController.value.copyWith(
        isLoading: false,
        tasks: event.tasks,
        error: null,
      ),
    );
  }

  void _handleTaskRetrieved(TaskRetrieved event) {
    dprint('Handling TaskRetrieved: ${event.task.id}');
    _updateState(
      _stateController.value.copyWith(
        isLoading: false,
        tasks: [
          ..._stateController.value.tasks.where((t) => t.id != event.task.id),
          event.task
        ],
        error: null,
      ),
    );
  }

  // Operation event handlers
  void _handleOperationInProgress(OperationInProgress event) {
    dprint('Handling OperationInProgress: ${event.operation}');
    _updateState(
      _stateController.value.copyWith(
        isLoading: true,
        error: null,
      ),
    );
  }

  void _handleOperationSuccess(OperationSuccess event) {
    dprint('Handling OperationSuccess: ${event.operation}');
    _updateState(
      _stateController.value.copyWith(
        isLoading: false,
        error: null,
      ),
    );
  }

  void _handleOperationFailure(OperationFailure event) {
    dprint('Handling OperationFailure: ${event.operation} - ${event.error}');
    _updateState(
      _stateController.value.copyWith(
        isLoading: false,
        error: event.error,
      ),
    );
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
    await _executeAuthenticatedOperation(
      'createNote',
      () => _createNoteUseCase.execute(CreateNoteParams(
        content: content,
        userId: _stateController.value.currentUser!.id,
      )),
    );
  }

  /// Helper method to execute operations that require authentication
  Future<T> _executeAuthenticatedOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    if (!_stateController.value.isAuthenticated) {
      throw NotAuthenticatedException('Must be authenticated to perform this operation');
    }

    _updateState(_stateController.value.copyWith(isLoading: true));
    
    try {
      final result = await operation();
      return result;
    } catch (e) {
      _updateState(_stateController.value.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
      throw NetworkOperationException(operationName, e.toString());
    }
  }

  @override
  Future<void> updateNote(String noteId, {String? content}) async {
    await _executeAuthenticatedOperation(
      'updateNote',
      () => _updateNoteUseCase.execute(UpdateNoteParams(
        noteId: noteId,
        content: content,
      )),
    );
  }

  @override
  Future<void> deleteNote(String noteId) async {
    await _executeAuthenticatedOperation(
      'deleteNote',
      () => _deleteNoteUseCase.execute(DeleteNoteParams(noteId: noteId)),
    );
  }

  @override
  Stream<Note> getNote(String noteId) {
    if (!_stateController.value.isAuthenticated) {
      throw NotAuthenticatedException('Must be authenticated to get notes');
    }
    
    _getNoteUseCase.execute(GetNoteParams(id: noteId));
    return _getNoteUseCase.note;
  }

  @override
  Future<List<Note>> listNotes({bool includeArchived = false}) async {
    return await _executeAuthenticatedOperation(
      'listNotes',
      () async {
        await _listNotesUseCase.execute(ListNotesParams(
          filters: {
            'user_id': _stateController.value.currentUser!.id,
            if (!includeArchived) 'archived': false,
          },
        ));
        return _stateController.value.notes;
      },
    );
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
    await _executeAuthenticatedOperation(
      'createTask',
      () => _createTaskUseCase.execute(CreateTaskParams(
        content: content,
        status: status ?? TaskStatus.todo,
        priority: priority ?? TaskPriority.medium,
        tags: tags,
        parentId: parentId,
        topicId: topicId,
      )),
    );
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
    await _executeAuthenticatedOperation(
      'updateTask',
      () => _updateTaskUseCase.execute(UpdateTaskParams(
        taskId: taskId,
        content: content,
        status: status,
        priority: priority,
        tags: tags,
        parentId: parentId,
        topicId: topicId,
      )),
    );
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await _executeAuthenticatedOperation(
      'deleteTask',
      () => _deleteTaskUseCase.execute(DeleteTaskParams(taskId: taskId)),
    );
  }

  @override
  Future<void> viewTask(String taskId) async {
    await _executeAuthenticatedOperation(
      'viewTask',
      () => _getTaskUseCase.execute(GetTaskParams(id: taskId)),
    );
  }

  @override
  Future<void> listTasks() async {
    await _executeAuthenticatedOperation(
      'listTasks',
      () => _listTasksUseCase.execute(ListTasksParams()),
    );
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
    // Cancel all subscriptions
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    
    // Close controllers in correct order
    await _publicStateController.close();
    await _stateController.close();
    await _events.close();
    
    dprint('Presenter resources disposed');
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