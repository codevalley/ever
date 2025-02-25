import 'dart:async';

import 'package:rxdart/rxdart.dart';
import '../../core/logging.dart';
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

/// CLI implementation of the Ever presenter
class CliPresenter implements EverPresenter {
  final RegisterUseCase _registerUseCase;
  final LoginUseCase _loginUseCase;
  final SignOutUseCase _signOutUseCase;
  final RefreshTokenUseCase _refreshTokenUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;

  // Note use cases
  final CreateNoteUseCase _createNoteUseCase;
  final UpdateNoteUseCase _updateNoteUseCase;
  final DeleteNoteUseCase _deleteNoteUseCase;
  final ListNotesUseCase _listNotesUseCase;
  final GetNoteUseCase _getNoteUseCase;

  // Task use cases
  final CreateTaskUseCase _createTaskUseCase;
  final UpdateTaskUseCase _updateTaskUseCase;
  final DeleteTaskUseCase _deleteTaskUseCase;
  final ListTasksUseCase _listTasksUseCase;
  final GetTaskUseCase _getTaskUseCase;

  final _stateController = BehaviorSubject<EverState>.seeded(EverState.initial());
  final _events = BehaviorSubject<DomainEvent>();
  final List<StreamSubscription> _subscriptions = [];

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
                 event is NotesRetrieved ||
                 event is NoteRetrieved) {
        _handleNoteEvents(event);
      } else if (event is TaskCreated ||
                 event is TaskUpdated ||
                 event is TaskDeleted ||
                 event is TasksRetrieved ||
                 event is TaskRetrieved) {
        _handleTaskEvents(event);
      } else if (event is OperationInProgress ||
                 event is OperationSuccess ||
                 event is OperationFailure) {
        // Handle generic operation events
        if (event is OperationInProgress) {
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
    iprint('CLI Presenter handling event: ${event.runtimeType}');
    
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
      dprint('CLI Presenter handling UserRegistered event');
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
    dprint('CLI Presenter handling token event: ${event.runtimeType}');
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
    dprint('CLI Presenter handling note event: ${event.runtimeType}');
    
    if (event is NoteCreated) {
      dprint('Note created: ${event.note.id}');
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          notes: [..._stateController.value.notes, event.note],
          error: null,
        ),
      );
    } else if (event is NoteUpdated) {
      dprint('Note updated: ${event.note.id}');
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
      dprint('Note deleted: ${event.noteId}');
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
      dprint('Notes retrieved: ${event.notes.length} notes');
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          notes: event.notes,
          error: null,
        ),
      );
    } else if (event is NoteRetrieved) {
      dprint('Note retrieved: ${event.note.id}');
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          notes: [
            ..._stateController.value.notes.where((n) => n.id != event.note.id),
            event.note
          ],
          error: null,
        ),
      );
    } else if (event is OperationInProgress) {
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
      eprint('Note operation failed: ${event.error}');
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          error: event.error,
        ),
      );
    }
  }

  void _handleTaskEvents(DomainEvent event) {
    dprint('CLI Presenter handling task event: ${event.runtimeType}');
    
    if (event is TaskCreated) {
      dprint('Task created: ${event.task.id}');
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          tasks: [..._stateController.value.tasks, event.task],
          error: null,
        ),
      );
    } else if (event is TaskUpdated) {
      dprint('Task updated: ${event.task.id}');
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          tasks: _stateController.value.tasks.map(
            (task) => task.id == event.task.id ? event.task : task
          ).toList(),
          error: null,
        ),
      );
    } else if (event is TaskDeleted) {
      dprint('Task deleted: ${event.taskId}');
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          tasks: _stateController.value.tasks.where(
            (task) => task.id != event.taskId
          ).toList(),
          error: null,
        ),
      );
    } else if (event is TasksRetrieved) {
      dprint('Tasks retrieved: ${event.tasks.length} tasks');
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          tasks: event.tasks,
          error: null,
        ),
      );
    } else if (event is OperationInProgress) {
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
      eprint('Task operation failed: ${event.error}');
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          error: event.error,
        ),
      );
    }
  }

  @override
  Future<void> register(String username) async {
    _updateState(EverState.initial().copyWith(isLoading: true));
    
    try {
      _registerUseCase.execute(RegisterParams(username: username));
      
      // Create a completer for registration
      final registerCompleter = Completer<void>();
      StreamSubscription? registerSubscription;
      
      registerSubscription = _registerUseCase.events.listen(
        (event) {
          dprint('Register event: ${event.runtimeType}');
          if (event is UserRegistered) {
            dprint('User registered successfully');
            if (!registerCompleter.isCompleted) registerCompleter.complete();
          } else if (event is OperationFailure) {
            eprint('Registration failed: ${event.error}');
            if (!registerCompleter.isCompleted) registerCompleter.completeError(Exception(event.error));
          }
        },
        onError: (error) {
          eprint('Registration stream error: $error');
          if (!registerCompleter.isCompleted) registerCompleter.completeError(error);
        },
        onDone: () {
          dprint('Registration stream completed');
          if (!registerCompleter.isCompleted) {
            registerCompleter.completeError(Exception('Registration stream completed without result'));
          }
        },
      );

      // Wait for registration with timeout
      try {
        await registerCompleter.future.timeout(Duration(seconds: 10));
      } catch (e) {
        eprint('Registration timeout: $e');
        throw Exception('Failed to register: $e');
      } finally {
        await registerSubscription.cancel();
      }
    } catch (e) {
      eprint('Registration failed: ${e.toString()}');
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
  Future<void> login(String userSecret) async {
    dprint('Starting login process');
    _updateState(EverState.initial().copyWith(isLoading: true));
    
    try {
      // First obtain token
      dprint('Obtaining token');
      _loginUseCase.execute(LoginParams(userSecret: userSecret));
      
      // Wait for token events to be processed
      var tokenObtained = false;
      var attempts = 0;
      while (!tokenObtained && attempts < 3) {
        attempts++;
        try {
          await for (final event in _loginUseCase.events.timeout(Duration(seconds: 10))) {
            dprint('Token event: ${event.runtimeType}');
            if (event is TokenObtained) {
              dprint('Token obtained in login flow');
              tokenObtained = true;
              break;
            } else if (event is OperationFailure) {
              throw Exception(event.error);
            }
          }
        } catch (e) {
          wprint('Token attempt $attempts failed: ${e.toString()}');
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
      dprint('Getting current user info');
      dprint('Executing getCurrentUserUseCase');
      _getCurrentUserUseCase.execute();
      
      // Create a completer to handle the user info retrieval
      final completer = Completer<void>();
      StreamSubscription? subscription;
      
      subscription = _getCurrentUserUseCase.events.listen(
        (event) {
          dprint('User info event: ${event.runtimeType}');
          if (event is CurrentUserRetrieved) {
            dprint('User info retrieved successfully');
            completer.complete();
          } else if (event is OperationFailure) {
            eprint('Failed to get user info: ${event.error}');
            completer.completeError(Exception(event.error));
          }
        },
        onError: (error) {
          eprint('User info stream error: $error');
          completer.completeError(error);
        },
        onDone: () {
          dprint('User info stream completed');
          if (!completer.isCompleted) {
            completer.completeError(Exception('User info stream completed without result'));
          }
        },
      );

      // Wait for completion with timeout
      try {
        await completer.future.timeout(Duration(seconds: 10));
      } catch (e) {
        eprint('User info timeout: $e');
        throw Exception('Failed to get user info: $e');
      } finally {
        await subscription.cancel();
      }
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
      rethrow;
    }
  }

  @override
  Future<void> updateNote(String noteId, {String? content}) async {
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
      rethrow;
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
      rethrow;
    }
  }

  @override
  Stream<Note> getNote(String noteId) {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to get notes');
    }
    
    _updateState(_stateController.value.copyWith(isLoading: true));
    
    // Use BehaviorSubject to handle the note stream
    final noteSubject = BehaviorSubject<Note>();
    var hasEmittedError = false;
    
    _getNoteUseCase.execute(GetNoteParams(id: noteId));
    
    var subscription = _getNoteUseCase.note.listen(
      (note) {
        if (!noteSubject.isClosed) {
          noteSubject.add(note);
        }
      },
      onError: (e) {
        if (!hasEmittedError && !noteSubject.isClosed) {
          hasEmittedError = true;
          noteSubject.addError(e);
        }
      },
      onDone: () {
        if (!noteSubject.isClosed) {
          noteSubject.close();
        }
      },
    );
    
    // Ensure subscription is cancelled when the stream is cancelled
    noteSubject.onCancel = () {
      subscription.cancel();
    };
    
    return noteSubject.stream;
  }

  @override
  Future<List<Note>> listNotes({bool includeArchived = false}) async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to list notes');
    }
    
    _updateState(_stateController.value.copyWith(isLoading: true));
    
    try {
      // Execute the use case
      await _listNotesUseCase.execute(ListNotesParams(
        filters: {
          'user_id': _stateController.value.currentUser!.id,
          if (!includeArchived) 'archived': false,
        },
      ));

      // Wait for the first emission from the notes stream
      final notes = await _listNotesUseCase.notes.first;
      
      _updateState(_stateController.value.copyWith(
        isLoading: false,
        notes: notes,
      ));

      return notes;
    } catch (e) {
      _updateState(_stateController.value.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
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
    
    _updateState(_stateController.value.copyWith(isLoading: true));
    
    try {
      await _createTaskUseCase.execute(CreateTaskParams(
        content: content,
        status: status ?? TaskStatus.todo,
        priority: priority ?? TaskPriority.medium,
        tags: tags,
        parentId: parentId,
        topicId: topicId,
      ));
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
    
    _updateState(_stateController.value.copyWith(isLoading: true));
    
    try {
      await _updateTaskUseCase.execute(UpdateTaskParams(
        taskId: taskId,
        content: content,
        status: status,
        priority: priority,
        dueDate: dueDate,
        tags: tags,
        parentId: parentId,
        topicId: topicId,
      ));
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
  Future<void> deleteTask(String taskId) async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to delete tasks');
    }
    
    _updateState(_stateController.value.copyWith(isLoading: true));
    
    try {
      await _deleteTaskUseCase.execute(DeleteTaskParams(taskId: taskId));
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
  Future<void> viewTask(String taskId) async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to view tasks');
    }
    
    _updateState(_stateController.value.copyWith(isLoading: true));
    
    try {
      await _getTaskUseCase.execute(GetTaskParams(id: taskId));
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
  Future<void> listTasks() async {
    if (!_stateController.value.isAuthenticated) {
      throw Exception('Must be authenticated to list tasks');
    }
    
    _updateState(_stateController.value.copyWith(isLoading: true));
    
    try {
      // Create a completer to wait for tasks
      final completer = Completer<void>();
      StreamSubscription? subscription;
      
      // Execute the use case
      _listTasksUseCase.execute(ListTasksParams());
      
      // Listen for events
      subscription = _listTasksUseCase.events.listen(
        (event) {
          if (event is TasksRetrieved) {
            _updateState(_stateController.value.copyWith(
              isLoading: false,
              tasks: event.tasks,
              error: null,
            ));
            if (!completer.isCompleted) completer.complete();
          } else if (event is OperationFailure) {
            if (!completer.isCompleted) {
              completer.completeError(Exception(event.error));
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.completeError(Exception('Task list stream completed without result'));
          }
        },
      );

      // Wait for completion with timeout
      try {
        await completer.future.timeout(Duration(seconds: 10));
      } catch (e) {
        _updateState(_stateController.value.copyWith(
          isLoading: false,
          error: e.toString(),
        ));
        rethrow;
      } finally {
        await subscription.cancel();
      }
    } catch (e) {
      _updateState(_stateController.value.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
      rethrow;
    }
  }

  @override
  Future<void> refresh() async {
    try {
      // Get current user first
      await getCurrentUser();
      
      // Only proceed with other operations if authenticated
      if (_stateController.value.isAuthenticated) {
        // Load notes and tasks in parallel
        await Future.wait([
          listNotes().catchError((e) {
            // Log error but don't fail refresh
            iprint('Error loading notes: $e');
            _updateState(_stateController.value.copyWith(
              notes: [], // Clear notes on error
              error: null,
            ));
            return <Note>[]; // Return empty list to satisfy Future<List<Note>>
          }),
          listTasks().catchError((e) {
            // Log error but don't fail refresh
            iprint('Error loading tasks: $e');
            _updateState(_stateController.value.copyWith(
              tasks: [], // Clear tasks on error
              error: null,
            ));
            return null; // may need to be looked at
          }),
        ]);
      }
    } catch (e) {
      // Update state with error but don't throw
      _updateState(_stateController.value.copyWith(
        error: 'Error during refresh: $e',
        isLoading: false,
      ));
    }
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _stateController.close();
    await _events.close();
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