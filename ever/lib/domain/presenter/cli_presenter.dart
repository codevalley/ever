import 'dart:async';

import 'package:rxdart/rxdart.dart';
import '../../core/logging.dart';
import '../core/events.dart';
import '../events/note_events.dart';
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
import '../entities/note.dart';
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

  final _stateController = BehaviorSubject<EverState>.seeded(EverState.initial());
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
  })  : _registerUseCase = registerUseCase,
        _loginUseCase = loginUseCase,
        _signOutUseCase = signOutUseCase,
        _refreshTokenUseCase = refreshTokenUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        _createNoteUseCase = createNoteUseCase,
        _updateNoteUseCase = updateNoteUseCase,
        _deleteNoteUseCase = deleteNoteUseCase,
        _listNotesUseCase = listNotesUseCase,
        _getNoteUseCase = getNoteUseCase {
    // Subscribe to all use case events
    _subscriptions.addAll([
      _registerUseCase.events.listen(_handleUserEvents),
      _loginUseCase.events.listen(_handleUserEvents),
      _signOutUseCase.events.listen(_handleUserEvents),
      _refreshTokenUseCase.events.listen(_handleTokenEvents),
      _getCurrentUserUseCase.events.listen(_handleUserEvents),
      _createNoteUseCase.events.listen(_handleNoteEvents),
      _updateNoteUseCase.events.listen(_handleNoteEvents),
      _deleteNoteUseCase.events.listen(_handleNoteEvents),
      _listNotesUseCase.events.listen(_handleNoteEvents),
      _getNoteUseCase.events.listen(_handleNoteEvents),
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
          error: null, // Clear any previous errors when starting new operation
        ),
      );
    } else if (event is OperationSuccess) {
      _updateState(
        _stateController.value.copyWith(
          isLoading: false,
          error: null, // Ensure error is cleared on success
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

  // Note Actions
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

  // Task Actions
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