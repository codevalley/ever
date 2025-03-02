# Simplified Flutter Presentation Approach

## Introduction

This document outlines a simplified approach for the Flutter presentation layer in the Ever app that builds on our existing Clean Architecture while reducing complexity and making state management more straightforward. The current implementation using the `FlutterEverPresenter` works well but could benefit from a more modern Flutter-centric approach using feature-focused Blocs/Cubits that better align with Flutter's reactive paradigm.

## Current Architecture Observations

The current `FlutterEverPresenter` has several strengths:
- Complete separation from domain layer via the `EverPresenter` interface
- Comprehensive event handling through RxDart streams
- Single source of truth with `EverState`

However, there are some challenges:
- Monolithic state object containing all UI state
- Complex event subscription management
- Limited feature isolation
- Manual state mapping from events

## Proposed Improvements

### 1. Feature-Based Presentation Modules

Instead of a single presenter handling all state, use multiple feature-specific Blocs/Cubits:

```dart
// Feature-specific BLoCs
class NoteBloc extends Bloc<NoteEvent, NoteState> {
  final CreateNoteUseCase _createNoteUseCase;
  final ListNotesUseCase _listNotesUseCase;
  // ... other note-related use cases
  
  NoteBloc({
    required CreateNoteUseCase createNoteUseCase,
    required ListNotesUseCase listNotesUseCase,
    // ... other dependencies
  }) : _createNoteUseCase = createNoteUseCase,
       _listNotesUseCase = listNotesUseCase,
       super(NoteState.initial()) {
    on<CreateNoteRequested>(_onCreateNoteRequested);
    on<LoadNotesRequested>(_onLoadNotesRequested);
    // ... other event handlers
  }
  
  Future<void> _onCreateNoteRequested(
    CreateNoteRequested event, 
    Emitter<NoteState> emit
  ) async {
    emit(state.copyWith(isLoading: true));
    
    try {
      await _createNoteUseCase.execute(CreateNoteParams(
        content: event.content,
        userId: event.userId,
      ));
      
      // Optionally refresh notes list after creation
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }
}
```

### 2. Simplified State Models

Use tailored state objects for each feature instead of a monolithic state:

```dart
// Feature-specific state
class NoteState {
  final bool isLoading;
  final List<Note> notes;
  final Note? selectedNote;
  final String? error;

  const NoteState({
    this.isLoading = false,
    this.notes = const [],
    this.selectedNote,
    this.error,
  });

  factory NoteState.initial() => const NoteState();

  NoteState copyWith({
    bool? isLoading,
    List<Note>? notes,
    Note? selectedNote,
    String? error,
  }) {
    // ... standard copyWith implementation
  }
}
```

### 3. Direct Use Case Event Integration

Leverage Flutter BLoC's ability to handle async events directly:

```dart
void _onLoadNotesRequested(
  LoadNotesRequested event,
  Emitter<NoteState> emit,
) async {
  emit(state.copyWith(isLoading: true));
  
  try {
    // Create a subscription to the use case events
    final notes = await _listNotesUseCase.execute(ListNotesParams(
      filters: event.filters,
    ));
    
    emit(state.copyWith(
      isLoading: false,
      notes: notes,
    ));
  } catch (e) {
    emit(state.copyWith(
      isLoading: false,
      error: e.toString(),
    ));
  }
}
```

### 4. Shared Auth/User Context

Extract authentication state into a shared context accessible to all features:

```dart
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final LoginUseCase _loginUseCase;
  final SignOutUseCase _signOutUseCase;
  
  AuthBloc({
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required LoginUseCase loginUseCase,
    required SignOutUseCase signOutUseCase,
  }) : _getCurrentUserUseCase = getCurrentUserUseCase,
       _loginUseCase = loginUseCase,
       _signOutUseCase = signOutUseCase,
       super(AuthState.initial()) {
    on<CheckAuthRequested>(_onCheckAuthRequested);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }
  
  // ... Event handlers
}
```

### 5. BLoC Providers and Consumer Pattern

Use Flutter BLoC's provider pattern for dependency injection and state access:

```dart
void main() {
  setupDependencies();
  runApp(const EverApp());
}

class EverApp extends StatelessWidget {
  const EverApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthBloc(
            getCurrentUserUseCase: getIt<GetCurrentUserUseCase>(),
            loginUseCase: getIt<LoginUseCase>(),
            signOutUseCase: getIt<SignOutUseCase>(),
          )..add(CheckAuthRequested()),
        ),
        BlocProvider(
          create: (context) => NoteBloc(
            createNoteUseCase: getIt<CreateNoteUseCase>(),
            listNotesUseCase: getIt<ListNotesUseCase>(),
            // ... other use cases
          ),
        ),
        // Other BLoC providers
      ],
      child: MaterialApp(
        title: 'Ever App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state.isAuthenticated) {
              return const HomePage();
            } else {
              return const LoginPage();
            }
          },
        ),
      ),
    );
  }
}
```

## Implementation Strategy

1. **Create Foundation**
   - Implement shared AuthBloc
   - Define base state patterns

2. **Migrate Feature by Feature**
   - Create feature-specific Blocs (NoteBloc, TaskBloc)
   - Update UI to use Bloc consumers
   - Test each feature independently

3. **Refine and Optimize**
   - Add loading/error handling utilities
   - Improve state transitions
   - Add analytics integration

## Benefits of This Approach

1. **Better Separation of Concerns**
   - Each feature has its own state management
   - Clearer data flow within features
   - More maintainable code organization

2. **Simplified State Mapping**
   - Direct async event handlers
   - No manual event-to-state transformation
   - More intuitive state updates

3. **Improved Testability**
   - Smaller, focused Blocs
   - Isolated feature testing
   - Easier to mock dependencies

4. **Better Flutter Integration**
   - Leverages Flutter BLoC ecosystem
   - Follows Flutter community best practices
   - More familiar to Flutter developers

## Compatibility with Existing Code

This approach is compatible with our existing Clean Architecture:
- Continues using the same domain layer (entities, use cases, repositories)
- Respects the same dependency direction (UI → Domain → Data)
- Maintains separation of concerns between layers
- Can be implemented incrementally alongside existing presenter

## Next Steps

1. Create a prototype for one feature (e.g., Notes)
2. Test with real use cases and data flow
3. Get feedback from the team
4. Create a full implementation plan
5. Begin gradual migration