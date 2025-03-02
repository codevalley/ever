# Flutter Presenter Improvement Plan

Based on the review of the existing `FlutterEverPresenter` implementation and our new Flutter presentation approach, this document outlines specific improvements that can be made to the current presenter while maintaining compatibility with the existing architecture.

## Current Implementation Analysis

`FlutterEverPresenter` shares much of its structure with `CliPresenter`, following a similar pattern of:

1. **Monolithic Event Handling**: All events from all use cases are merged into a single stream
2. **Manual Event-to-State Mapping**: Complex mapping logic in event handler methods
3. **Global State Management**: Single `EverState` instance containing all application state
4. **Complex Subscription Management**: Many subscriptions that need to be carefully managed

## Immediate Improvements

These changes can be implemented without a major architectural overhaul:

### 1. Improved Event Handling

Replace the complex nested if-else event handling structure with a more declarative pattern:

```dart
// BEFORE:
_subscriptions.add(_events.stream.listen((event) {
  if (event is CurrentUserRetrieved || event is UserRegistered || event is UserLoggedOut) {
    _handleUserEvents(event);
  } else if (event is TokenObtained || event is TokenRefreshed || event is TokenExpired) {
    _handleTokenEvents(event);
  }
  // ...more complex conditions
}));

// AFTER:
final _eventHandlers = <Type, Function(DomainEvent)>{
  CurrentUserRetrieved: (event) => _handleUserRetrieved(event as CurrentUserRetrieved),
  UserRegistered: (event) => _handleUserRegistered(event as UserRegistered),
  UserLoggedOut: (event) => _handleUserLoggedOut(event as UserLoggedOut),
  TokenObtained: (event) => _handleTokenObtained(event as TokenObtained),
  // ...more handlers
};

_subscriptions.add(_events.stream.listen((event) {
  final handler = _eventHandlers[event.runtimeType];
  if (handler != null) {
    handler(event);
  } else if (event is OperationInProgress) {
    _handleOperationInProgress(event);
  } else if (event is OperationSuccess) {
    _handleOperationSuccess(event);
  } else if (event is OperationFailure) {
    _handleOperationFailure(event);
  }
}));
```

### 2. More Selective State Updates

Reduce unnecessary state emissions by being more selective about what state properties are updated:

```dart
// BEFORE:
_updateState(
  _stateController.value.copyWith(
    isLoading: false,
    currentUser: event.user,
    isAuthenticated: event.user != null,
    error: null,
  ),
);

// AFTER:
final updatedProps = <String, dynamic>{
  'isLoading': false,
  'currentUser': event.user,
  'isAuthenticated': event.user != null,
};

// Only update error if it was previously set
if (_stateController.value.error != null) {
  updatedProps['error'] = null;
}

_updateState(_stateController.value.copyWithMap(updatedProps));
```

### 3. Improved Async Method Handling

Make the async methods more consistent with proper error handling:

```dart
// BEFORE:
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

// AFTER:
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

/// Helper to execute authenticated operations with consistent error handling
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
    rethrow;
  }
}
```

### 4. Improved Stream Resource Management

Better management of stream resources to prevent memory leaks:

```dart
// Add a utility method for subscription management
void _addSubscription(StreamSubscription subscription) {
  _subscriptions.add(subscription);
}

// Add an interval-based state debouncer
void _setupStateDebouncer() {
  // Only emit state events at most once every 100ms to avoid UI flicker
  final debouncedStateController = BehaviorSubject<EverState>.seeded(_stateController.value);
  
  _addSubscription(
    _stateController.stream
      .debounceTime(Duration(milliseconds: 100))
      .distinct() // Only emit when state changes
      .listen(debouncedStateController.add)
  );
  
  // Replace the exposed state stream with the debounced version
  _publicStateController = debouncedStateController;
}

@override
Stream<EverState> get state => _publicStateController.stream;
```

### 5. Add Domain-Specific Exceptions

Create domain-specific exceptions instead of generic ones:

```dart
/// Authentication exception
class NotAuthenticatedException implements Exception {
  final String message;
  NotAuthenticatedException(this.message);
  @override
  String toString() => 'NotAuthenticatedException: $message';
}

/// Network operation exception
class NetworkOperationException implements Exception {
  final String operation;
  final String message;
  NetworkOperationException(this.operation, this.message);
  @override
  String toString() => 'NetworkOperationException[$operation]: $message';
}

// Usage
if (!_stateController.value.isAuthenticated) {
  throw NotAuthenticatedException('Must be authenticated to update notes');
}
```

## Medium-Term Improvements

These changes require more substantial refactoring but can still be implemented without a complete redesign:

### 1. Split State Into Feature-Specific State Containers

Divide the monolithic state into feature-specific containers:

```dart
class EverState {
  final AuthState auth;
  final NotesState notes;
  final TasksState tasks;
  final bool isLoading;
  final String? error;

  const EverState({
    required this.auth,
    required this.notes,
    required this.tasks,
    this.isLoading = false,
    this.error,
  });

  // Feature-specific state containers
  class AuthState {
    final bool isAuthenticated;
    final User? currentUser;
    
    const AuthState({
      this.isAuthenticated = false,
      this.currentUser,
    });
    
    AuthState copyWith({bool? isAuthenticated, User? currentUser}) {
      return AuthState(
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        currentUser: currentUser ?? this.currentUser,
      );
    }
  }
  
  class NotesState {
    final List<Note> notes;
    final Note? selectedNote;
    
    const NotesState({
      this.notes = const [],
      this.selectedNote,
    });
    
    // Add copyWith method
  }
  
  class TasksState {
    final List<Task> tasks;
    final Task? selectedTask;
    
    const TasksState({
      this.tasks = const [],
      this.selectedTask,
    });
    
    // Add copyWith method
  }
  
  // Make the copyWith method more modular
  EverState copyWith({
    AuthState? auth,
    NotesState? notes,
    TasksState? tasks,
    bool? isLoading,
    String? error,
  }) {
    return EverState(
      auth: auth ?? this.auth,
      notes: notes ?? this.notes,
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
```

### 2. Add Reactive Property Support

Add support for observing specific pieces of state without subscribing to all changes:

```dart
// Add selective state access methods
Stream<bool> get isAuthenticated => 
  state.map((state) => state.auth.isAuthenticated).distinct();
  
Stream<User?> get currentUser => 
  state.map((state) => state.auth.currentUser).distinct();
  
Stream<List<Note>> get notes =>
  state.map((state) => state.notes.notes).distinct();
  
Stream<List<Task>> get tasks =>
  state.map((state) => state.tasks.tasks).distinct();
  
Stream<bool> get isLoading =>
  state.map((state) => state.isLoading).distinct();
  
Stream<String?> get error =>
  state.map((state) => state.error).distinct();
```

### 3. Add Event-Based Operations

Transition to an event-based system that supports both imperative and reactive styles:

```dart
// Add event-based operation methods alongside imperative ones
void dispatchEvent(PresenterEvent event) {
  if (event is LoginRequested) {
    login(event.userSecret);
  } else if (event is RegisterRequested) {
    register(event.username);
  } else if (event is CreateNoteRequested) {
    createNote(event.content);
  }
  // More event handlers
}

// Example usage in UI
presenter.dispatchEvent(LoginRequested('user123'));

// Or use the direct method
await presenter.login('user123');
```

## Long-Term Vision

The long-term plan is to transition towards the approach outlined in `flutter_presentation_approach.md`:

1. Create feature-specific BLoCs that interact with the domain layer directly
2. Gradually migrate features away from the monolithic presenter
3. Eventually replace the presenter with a set of coordinated BLoCs

This transition can be made gradually:

1. Begin by adding the new BLoC patterns alongside the presenter
2. Refactor the UI to use the BLoCs for state management
3. Update features one by one to use the new approach
4. Once all features are migrated, the presenter can be removed

## Implementation Priority

1. **Immediate Improvements**: Improve event handling, state update logic, and error handling
2. **Medium-Term**: Refactor state into feature containers and add reactive property support
3. **Long-Term**: Begin migration toward feature-specific BLoCs

## Recommendations

Based on this analysis, we recommend:

1. Implementing the immediate improvements to enhance the current presenter
2. Beginning work on a prototype of the NoteBloc following the new pattern
3. Testing the prototype with a simple UI component
4. If successful, develop a comprehensive migration plan