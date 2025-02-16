# Ever App - Phase 1 Planning Document

## Technology Choices Discussion

### State Management
Currently specified: `flutter_bloc`
Alternative: Vanilla State Management

**Considerations:**
1. **Vanilla State Management**
   - Pros:
     - Simpler to understand and maintain
     - No additional dependencies
     - Sufficient for basic CRUD operations
     - Better for small to medium apps
   - Cons:
     - Manual state handling
     - No built-in separation of concerns
     - More boilerplate for complex states

2. **flutter_bloc**
   - Pros:
     - Enforced separation of concerns
     - Built-in state management patterns
     - Good for complex state flows
     - Great DevTools support
   - Cons:
     - Learning curve
     - Might be overkill for simple CRUD
     - Additional dependency

**Recommendation:** Use flutter_bloc
- Reasoning: 
  - Clear separation of concerns from the start
  - Better testability of business logic
  - Built-in debugging tools
  - More maintainable as app complexity grows
  - Consistent state management pattern across features

### Local Storage
Currently specified: `sqflite`
Alternative: `isar` or `hive`

**Considerations:**
1. **sqflite**
   - Pros:
     - Mature and stable
     - SQL queries for complex data
     - Transaction support
   - Cons:
     - Not reactive by default
     - More verbose queries
     - Platform-specific code needed

2. **isar**
   - Pros:
     - Fully reactive
     - Cross-platform (including web)
     - Better performance
     - Type-safe queries
     - Built-in indexing
   - Cons:
     - Newer technology
     - Smaller community

**Recommendation:** Switch to `isar`
- Reasoning:
  - Better web support (important for our cross-platform needs)
  - Reactive by default (better for real-time updates)
  - More modern API
  - Better performance

## Project Structure

```
lib/
├── domain/              # All interfaces and entities
│   ├── datasources/     # Data source interfaces
│   │   ├── base_ds.dart
│   │   ├── user_ds.dart
│   │   ├── note_ds.dart
│   │   └── task_ds.dart
│   ├── entities/        # Pure domain entities
│   │   ├── user.dart
│   │   ├── note.dart
│   │   └── task.dart
│   ├── repositories/    # Repository interfaces
│   │   ├── base_repository.dart
│   │   ├── user_repository.dart
│   │   ├── note_repository.dart
│   │   └── task_repository.dart
│   ├── presenter/       # Presenter interface
│   │   ├── ever_presenter.dart  # Single presenter interface
│   │   └── ever_state.dart      # App state definition
│   └── usecases/        # Business logic interfaces
│       ├── base_usecase.dart
│       ├── user/
│       ├── note/
│       └── task/
└── implementations/     # Concrete implementations
    ├── datasources/     # Data source implementations
    │   ├── base_ds_rest.dart
    │   ├── user_ds_rest.dart
    │   ├── note_ds_rest.dart
    │   └── task_ds_rest.dart
    ├── models/          # Data models
    │   ├── base_model.dart
    │   ├── user_model.dart
    │   ├── note_model.dart
    │   └── task_model.dart
    ├── presenter/       # Presenter implementation
    │   └── flutter_ever_presenter.dart  # Flutter-specific implementation
    ├── repositories/    # Repository implementations
    │   ├── user_repo_impl.dart
    │   ├── note_repo_impl.dart
    │   └── task_repo_impl.dart
    └── ui/             # UI Layer
        ├── pages/      # Screens
        └── widgets/    # Reusable widgets

```

## Architecture Overview

### Reactive Design Principles
1. **Event-Driven Architecture**
   - All operations are non-blocking
   - State changes are propagated through streams
   - UI reacts to state changes, never waits for operations

2. **Data Flow**
   ```
   UI -> Presenter -> UseCase -> Repository -> DataSource -> API
                                                        <- Event
   UI <- State    <- State   <- Event    <- Event     <- Response
   ```

3. **Key Concepts**
   - DataSources emit events, don't return futures
   - Repositories transform events into domain events
   - UseCases coordinate business logic and state updates
   - Presenter maintains UI state and reacts to domain events

## Phase 1 Implementation Plan

### Epic 1: Core Domain Layer ✅
1. **Events & Types** ✅
   - [x] Create base domain event types
   - [x] Define operation events (Progress, Success, Failure)
   - [x] Create core entity interfaces

2. **Base Interfaces** ✅
   - [x] Create reactive data source interface (Stream-based)
   - [x] Create reactive repository interface (Event-based)
   - [x] Create reactive use case interface (State-based)

### Epic 2: Feature Interfaces
1. **User Domain** ✅
   - [x] Define User entity
   - [x] Create user data source interface
   - [x] Define user-specific events
   - [x] Create user repository interface
   - [x] Define user use cases

2. **Note Domain**
   - [x] Define Note entity
   - [ ] Define note-specific events
   - [ ] Create note data source interface
   - [ ] Create note repository interface
   - [ ] Define note use cases

3. **Task Domain**
   - [x] Define Task entity
   - [ ] Define task-specific events
   - [ ] Create task data source interface
   - [ ] Create task repository interface
   - [ ] Define task use cases

### Epic 3: Feature Implementations
1. **User Implementation** 🔄
   - [x] Create user-specific events (UserRegistered, TokenObtained, etc.)
   - [x] Create API configuration and constants
   - [x] Create user model with domain mapping
   - [x] Implement REST data source with Isar storage
   - [x] Implement repository with proper domain separation
   - [x] Update use cases to work with domain objects
      - [x] RegisterUseCase (with input validation)
      - [x] ObtainTokenUseCase (with token management)
      - [x] RefreshTokenUseCase (with auto-refresh)
      - [x] GetCurrentUserUseCase (with proper error handling)
      - [x] SignOutUseCase (with edge case handling)
   - [x] Add comprehensive error handling
   - [ ] Add unit tests for components:
      - [ ] User entity tests
      - [ ] Repository tests
      - [ ] Use case tests:
         - [ ] RegisterUseCase
         - [ ] ObtainTokenUseCase
         - [ ] RefreshTokenUseCase
         - [ ] GetCurrentUserUseCase
         - [ ] SignOutUseCase

2. **Note Implementation**
   - [ ] Create note-specific events
   - [ ] Implement REST data source
   - [ ] Implement repository
   - [ ] Implement use cases

3. **Task Implementation**
   - [ ] Create task-specific events
   - [ ] Implement REST data source
   - [ ] Implement repository
   - [ ] Implement use cases

### Epic 4: Testing & Documentation
1. **Unit Tests**
   - [ ] Test data sources
   - [ ] Test repositories
   - [ ] Test use cases
   - [ ] Test event transformations

2. **Integration Tests**
   - [ ] Test authentication flow
   - [ ] Test error handling
   - [ ] Test token refresh flow

3. **Documentation**
   - [ ] API documentation
   - [ ] Architecture documentation
   - [ ] Testing documentation

### Current Focus: User Implementation
1. **Immediate Tasks**
   - [ ] Update use cases to properly handle domain objects
   - [ ] Ensure proper error propagation through layers
   - [ ] Add retry policies for network operations
   - [ ] Add comprehensive unit tests

2. **Design Decisions**
   - Using Isar for secure credential storage
   - Proper separation between domain and implementation
   - Reactive event-driven architecture
   - Clean mapping between API, models, and domain objects

3. **Quality Checks**
   - [ ] Code coverage > 80%
   - [ ] No direct API dependencies in domain layer
   - [ ] Proper error handling at each layer
   - [ ] Consistent event transformation

2. **Note Implementation**
   - [ ] Create note-specific events
   - [ ] Implement REST data source
   - [ ] Implement repository
   - [ ] Implement use cases

3. **Task Implementation**
   - [ ] Create task-specific events
   - [ ] Implement REST data source
   - [ ] Implement repository
   - [ ] Implement use cases

### Epic 4: Presenter Layer
1. **State Management**
   - [ ] Define app state structure
   - [ ] Create state update mechanisms
   - [ ] Define state transitions

2. **Presenter Interface**
   - [ ] Define presenter operations
   - [ ] Create event handling methods
   - [ ] Define state stream interface

3. **Flutter Implementation**
   - [ ] Implement presenter
   - [ ] Create state management logic
   - [ ] Implement event handling

### Epic 2: User Management
1. **User Entity Implementation**
   - [ ] Create user domain entity
   - [ ] Implement user repository
   - [ ] Setup user local storage
   - [ ] Add user authentication

### Epic 3: Notes Feature
1. **Notes Core**
   - [ ] Create note domain entity
   - [ ] Implement notes repository
   - [ ] Setup notes storage
   - [ ] Add note CRUD operations

### Epic 4: Tasks Feature
1. **Tasks Core**
   - [ ] Create task domain entity
   - [ ] Implement tasks repository
   - [ ] Setup tasks storage
   - [ ] Add task CRUD operations

## Implementation Priority
1. User Management (Authentication is prerequisite)
2. Notes Feature (Core functionality)
3. Tasks Feature (Additional functionality)

## Technical Debt Considerations
- Proper error handling
- Comprehensive testing
- Offline support
- Data sync mechanisms
- Performance optimization

## Next Steps
1. Update dependencies in pubspec.yaml
2. Setup core architecture
3. Begin with User Management implementation
