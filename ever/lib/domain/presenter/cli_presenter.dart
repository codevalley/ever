import 'dart:async';

import '../core/events.dart';
import '../entities/note.dart';
import '../entities/task.dart';
import '../events/note_events.dart';
import '../events/task_events.dart';
import '../events/user_events.dart';
import '../usecases/user/get_current_user_usecase.dart';
import '../usecases/user/login_usecase.dart';
import '../usecases/user/refresh_token_usecase.dart';
import '../usecases/user/register_usecase.dart';
import '../usecases/user/sign_out_usecase.dart';
import '../usecases/note/create_note_usecase.dart';
import '../usecases/note/update_note_usecase.dart';
import '../usecases/note/delete_note_usecase.dart';
import '../usecases/note/list_notes_usecase.dart';
import '../usecases/note/get_note_usecase.dart';
import '../usecases/task/create_task_usecase.dart';
import '../usecases/task/update_task_usecase.dart';
import '../usecases/task/delete_task_usecase.dart';
import '../usecases/task/list_tasks_usecase.dart';
import '../usecases/task/get_task_usecase.dart';
import 'ever_presenter.dart';

class CliPresenter implements EverPresenter {
  final RegisterUseCase _registerUseCase;
  final LoginUseCase _loginUseCase;
  final SignOutUseCase _signOutUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final CreateNoteUseCase _createNoteUseCase;
  final UpdateNoteUseCase _updateNoteUseCase;
  final DeleteNoteUseCase _deleteNoteUseCase;
  final ListNotesUseCase _listNotesUseCase;
  final GetNoteUseCase _getNoteUseCase;
  final CreateTaskUseCase _createTaskUseCase;
  final UpdateTaskUseCase _updateTaskUseCase;
  final DeleteTaskUseCase _deleteTaskUseCase;
  final ListTasksUseCase _listTasksUseCase;
  final GetTaskUseCase _getTaskUseCase;

  final _stateController = StreamController<EverState>.broadcast();
  EverState _currentState = EverState.initial();

  CliPresenter({
    required RegisterUseCase registerUseCase,
    required LoginUseCase loginUseCase,
    required SignOutUseCase signOutUseCase,
    required RefreshTokenUseCase refreshTokenUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required CreateNoteUseCase createNoteUseCase,
    required UpdateNoteUseCase updateNoteUseCase,
    required DeleteNoteUseCase deleteNoteUseCase,
    required ListNotesUseCase listNotesUseCase,
    required GetNoteUseCase getNoteUseCase,
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
        _listNotesUseCase = listNotesUseCase,
        _getNoteUseCase = getNoteUseCase,
        _createTaskUseCase = createTaskUseCase,
        _updateTaskUseCase = updateTaskUseCase,
        _deleteTaskUseCase = deleteTaskUseCase,
        _listTasksUseCase = listTasksUseCase,
        _getTaskUseCase = getTaskUseCase {
    _setupEventHandlers();
  }

  void _setupEventHandlers() {
    _registerUseCase.events.listen(_handleUserEvents);
    _loginUseCase.events.listen(_handleUserEvents);
    _signOutUseCase.events.listen(_handleUserEvents);
    _refreshTokenUseCase.events.listen(_handleUserEvents);
    _getCurrentUserUseCase.events.listen(_handleUserEvents);
    _createNoteUseCase.events.listen(_handleNoteEvents);
    _updateNoteUseCase.events.listen(_handleNoteEvents);
    _deleteNoteUseCase.events.listen(_handleNoteEvents);
    _listNotesUseCase.events.listen(_handleNoteEvents);
    _getNoteUseCase.events.listen(_handleNoteEvents);
    _createTaskUseCase.events.listen(_handleTaskEvents);
    _updateTaskUseCase.events.listen(_handleTaskEvents);
    _deleteTaskUseCase.events.listen(_handleTaskEvents);
    _listTasksUseCase.events.listen(_handleTaskEvents);
    _getTaskUseCase.events.listen(_handleTaskEvents);
  }

  void _updateState(EverState newState) {
    _currentState = newState;
    _stateController.add(_currentState);
  }

  void _handleUserEvents(DomainEvent event) {
    if (event is OperationInProgress) {
      _updateState(_currentState.copyWith(isLoading: true));
    } else if (event is OperationSuccess) {
      _updateState(_currentState.copyWith(isLoading: false, error: null));
    } else if (event is OperationFailure) {
      _updateState(_currentState.copyWith(
        isLoading: false,
        error: event.error.toString(),
      ));
    } else if (event is UserRegistered) {
      _updateState(_currentState.copyWith(
        currentUser: event.user,
        isAuthenticated: true,
      ));
    } else if (event is TokenObtained) {
      _updateState(_currentState.copyWith(
        isLoading: false,
        error: null,
      ));
    } else if (event is UserLoggedOut) {
      _updateState(EverState.initial());
    } else if (event is CurrentUserRetrieved) {
      _updateState(_currentState.copyWith(
        currentUser: event.user,
        isAuthenticated: true,
      ));
    }
  }

  void _handleNoteEvents(DomainEvent event) {
    if (event is OperationInProgress) {
      _updateState(_currentState.copyWith(isLoading: true));
    } else if (event is OperationSuccess) {
      _updateState(_currentState.copyWith(isLoading: false, error: null));
    } else if (event is OperationFailure) {
      _updateState(_currentState.copyWith(
        isLoading: false,
        error: event.error.toString(),
      ));
    } else if (event is NoteCreated) {
      final updatedNotes = List<Note>.from(_currentState.notes)..add(event.note);
      _updateState(_currentState.copyWith(notes: updatedNotes));
    } else if (event is NoteUpdated) {
      final updatedNotes = List<Note>.from(_currentState.notes)
        ..removeWhere((note) => note.id == event.note.id)
        ..add(event.note);
      _updateState(_currentState.copyWith(notes: updatedNotes));
    } else if (event is NoteDeleted) {
      final updatedNotes = List<Note>.from(_currentState.notes)
        ..removeWhere((note) => note.id == event.noteId);
      _updateState(_currentState.copyWith(notes: updatedNotes));
    } else if (event is NotesRetrieved) {
      _updateState(_currentState.copyWith(notes: event.notes));
    }
  }

  void _handleTaskEvents(DomainEvent event) {
    if (event is OperationInProgress) {
      _updateState(_currentState.copyWith(isLoading: true));
    } else if (event is OperationSuccess) {
      _updateState(_currentState.copyWith(isLoading: false, error: null));
    } else if (event is OperationFailure) {
      _updateState(_currentState.copyWith(
        isLoading: false,
        error: event.error.toString(),
      ));
    } else if (event is TaskCreated) {
      final updatedTasks = List<Task>.from(_currentState.tasks)..add(event.task);
      _updateState(_currentState.copyWith(tasks: updatedTasks));
    } else if (event is TaskUpdated) {
      final updatedTasks = List<Task>.from(_currentState.tasks)
        ..removeWhere((task) => task.id == event.task.id)
        ..add(event.task);
      _updateState(_currentState.copyWith(tasks: updatedTasks));
    } else if (event is TaskDeleted) {
      final updatedTasks = List<Task>.from(_currentState.tasks)
        ..removeWhere((task) => task.id == event.taskId);
      _updateState(_currentState.copyWith(tasks: updatedTasks));
    } else if (event is TasksRetrieved) {
      _updateState(_currentState.copyWith(tasks: event.tasks));
    }
  }

  @override
  Stream<EverState> get state => _stateController.stream;

  @override
  Future<void> initialize() async {
    await refresh();
  }

  @override
  Future<void> register(String username) async {
    _registerUseCase.execute(RegisterParams(username: username));
  }

  @override
  Future<void> login(String userSecret) async {
    _loginUseCase.execute(LoginParams(userSecret: userSecret));
  }

  @override
  Future<void> logout() async {
    _signOutUseCase.execute();
  }

  @override
  Future<void> refreshSession() async {
    _refreshTokenUseCase.execute();
  }

  @override
  Future<void> getCurrentUser() async {
    _getCurrentUserUseCase.execute();
  }

  @override
  Future<void> createNote(String content) async {
    if (!_currentState.isAuthenticated) {
      throw Exception('Must be authenticated to create notes');
    }
    _createNoteUseCase.execute(CreateNoteParams(
      content: content,
      userId: _currentState.currentUser!.id,
    ));
  }

  @override
  Future<void> updateNote(String noteId, {String? content}) async {
    if (!_currentState.isAuthenticated) {
      throw Exception('Must be authenticated to update notes');
    }
    _updateNoteUseCase.execute(UpdateNoteParams(
      noteId: noteId,
      content: content,
    ));
  }

  @override
  Future<void> deleteNote(String noteId) async {
    if (!_currentState.isAuthenticated) {
      throw Exception('Must be authenticated to delete notes');
    }
    _deleteNoteUseCase.execute(DeleteNoteParams(noteId: noteId));
  }

  @override
  Stream<Note> getNote(String noteId) {
    if (!_currentState.isAuthenticated) {
      throw Exception('Must be authenticated to get notes');
    }
    _getNoteUseCase.execute(GetNoteParams(id: noteId));
    return _getNoteUseCase.note;
  }

  @override
  Future<List<Note>> listNotes({bool includeArchived = false}) async {
    if (!_currentState.isAuthenticated) {
      throw Exception('Must be authenticated to list notes');
    }
    _listNotesUseCase.execute(ListNotesParams(
      filters: {
        if (!includeArchived) 'archived': false,
      },
    ));
    return _currentState.notes;
  }

  @override
  Future<void> createTask({required String title, String? description}) async {
    if (!_currentState.isAuthenticated) {
      throw Exception('Must be authenticated to create tasks');
    }
    _createTaskUseCase.execute(CreateTaskParams(
      content: title,
      status: TaskStatus.todo,
      priority: TaskPriority.medium,
      tags: description != null ? [description] : [],
    ));
  }

  @override
  Future<void> updateTask(String taskId, {String? title, String? description, String? status}) async {
    if (!_currentState.isAuthenticated) {
      throw Exception('Must be authenticated to update tasks');
    }
    _updateTaskUseCase.execute(UpdateTaskParams(
      taskId: taskId,
      content: title,
      status: status != null ? _parseTaskStatus(status) : null,
    ));
  }

  TaskStatus _parseTaskStatus(String status) {
    switch (status.toLowerCase()) {
      case 'todo':
        return TaskStatus.todo;
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'done':
        return TaskStatus.done;
      default:
        throw ArgumentError('Invalid task status: $status');
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    if (!_currentState.isAuthenticated) {
      throw Exception('Must be authenticated to delete tasks');
    }
    _deleteTaskUseCase.execute(DeleteTaskParams(taskId: taskId));
  }

  @override
  Future<void> viewTask(String taskId) async {
    if (!_currentState.isAuthenticated) {
      throw Exception('Must be authenticated to view tasks');
    }
    _getTaskUseCase.execute(GetTaskParams(id: taskId));
  }

  @override
  Future<void> listTasks() async {
    if (!_currentState.isAuthenticated) {
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
    await _stateController.close();
  }

  @override
  Future<String?> getCachedUserSecret() async {
    // This should be implemented by getting the user secret from the cache
    // For now, return null as we haven't implemented the cache logic yet
    return null;
  }
} 