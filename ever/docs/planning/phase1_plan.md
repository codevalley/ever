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

2. **Note Domain** ✅
   - [x] Define Note entity
   - [x] Define note-specific events
   - [x] Create note data source interface
   - [x] Create note repository interface
   - [x] Define note use cases

3. **Task Domain** ✅
   - [x] Define Task entity
   - [x] Define task-specific events
   - [x] Create task data source interface
   - [x] Create task repository interface
   - [x] Define task use cases

### Epic 3: Feature Implementations
1. **User Implementation** ✅
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
   - [x] Add resilience patterns
      - [x] Retry mechanism with exponential backoff
      - [x] Circuit breaker pattern
      - [x] Event-driven error handling
   - [x] Add unit tests for components:
      - [x] User entity tests
      - [x] Data source tests:
         - [x] REST API integration
         - [x] Local storage (Isar)
         - [x] Error handling
         - [x] Event emission
      - [x] Repository tests:
         - [x] Event transformation
         - [x] Domain mapping
         - [x] Error handling
      - [x] Use case tests:
         - [x] RegisterUseCase
         - [x] ObtainTokenUseCase
         - [x] RefreshTokenUseCase
         - [x] GetCurrentUserUseCase
         - [x] SignOutUseCase
   - [x] Add presenter layer
      - [x] Create EverPresenter interface
      - [x] Create FlutterEverPresenter implementation
      - [x] Add state management
      - [x] Add event handling
      - [x] Add user authentication flow

2. **Note Implementation** ✅
   - [x] Create note-specific events
   - [x] Implement REST data source with resilience patterns
   - [x] Implement repository with event transformation
   - [x] Implement use cases with proper error handling
   - [x] Add presenter support for notes
      - [x] Add note state management
      - [x] Add note event handling
      - [x] Add note CRUD operations

3. **Task Implementation** ✅
   - [x] Create task-specific events
   - [x] Implement REST data source with resilience patterns
   - [x] Implement repository with event transformation
   - [x] Implement use cases with proper error handling
   - [x] Add presenter support for tasks
      - [x] Add task state management
      - [x] Add task event handling
      - [x] Add task CRUD operations
   - [ ] Add topic management (in progress)
      - [ ] Implement Topic entity and model
      - [ ] Add Topic data source and repository
      - [ ] Create Topic use cases
      - [ ] Add CLI commands for topic management

### Epic 4: Testing & Documentation
1. **Unit Tests** ✅
   - [x] Test data sources
   - [x] Test repositories
   - [x] Test use cases
   - [x] Test event transformations
   - [x] Test resilience patterns
      - [x] Retry mechanism behavior
      - [x] Circuit breaker states
      - [x] Event propagation
   - [x] Test presenter
      - [x] State management
      - [x] Event handling
      - [x] Authentication flow

2. **Integration Tests** ✅
   - [x] Test authentication flow
   - [x] Test error handling
   - [x] Test token refresh flow
   - [x] Test resilience patterns
      - [x] Retry with network failures
      - [x] Circuit breaker state transitions
      - [x] Recovery scenarios
   - [x] Test presenter integration
      - [x] State updates
      - [x] Event propagation
      - [x] Use case coordination

3. **Documentation** 🔄
   - [x] Architecture documentation
      - [x] Reactive patterns in reactive-architecture.md
      - [x] Event handling guidelines
      - [x] Resilience patterns configuration
      - [x] Presenter layer design
   - [x] Testing documentation
      - [x] Unit testing guidelines
      - [x] Integration testing examples
      - [x] Presenter testing patterns
   - [x] API documentation (partially complete)
      - [x] Public interfaces
      - [ ] Usage examples (in progress)
      - [x] Error handling
      - [x] State management

4. **UseCase Review & Testing** ✅
   - [x] User Usecases Review
      - [x] Login (ObtainToken) UseCase
         - [x] Move resilience patterns to repository layer
         - [x] Update error handling with domain events
         - [x] Add comprehensive unit tests
         - [x] Add integration tests with repository
      - [x] Register UseCase
         - [x] Review and update implementation
         - [x] Add comprehensive unit tests
         - [x] Add integration tests
      - [x] Sign Out UseCase
         - [x] Review and update implementation
         - [x] Add comprehensive unit tests
         - [x] Add integration tests
      - [x] Refresh Token UseCase
         - [x] Review and update implementation
         - [x] Add comprehensive unit tests
         - [x] Add token expiration monitoring
         - [x] Add automatic refresh mechanism
      - [x] Get Current User UseCase
         - [x] Review and update implementation
         - [x] Add comprehensive unit tests
         - [x] Add integration tests
      - [-] Update Profile UseCase
         - [-] Remove implementation as endpoint not available in API
         - [-] Document removal in technical debt

### Current Focus: Topic Management Implementation
1. **Immediate Tasks**
   - [ ] Create Topic entity and model
   - [ ] Implement Topic data source interface
   - [ ] Add resilience patterns to Topic repository
   - [ ] Implement Topic usecases with proper error handling
   - [ ] Add presenter support for Topics
   - [ ] Add CLI commands for Topic management

2. **Design Decisions**
   - Keep usecases focused on domain logic
   - Infrastructure concerns (retry, circuit breaker) in repository layer
   - Clear event-based communication between layers
   - Strong input validation in usecases
   - Comprehensive error handling at each layer
   - State management in presenter layer
   - UI-agnostic presenter interface

3. **Quality Checks**
   - [x] Infrastructure concerns isolated to repository layer
   - [x] Test coverage > 90% for implemented components
   - [x] Proper event transformation in all cases
   - [x] Clear documentation for implemented components
   - [x] State management follows reactive patterns
   - [x] Event handling is consistent across layers

## Technical Debt Considerations
- [x] Proper error handling
- [x] Comprehensive testing
- [ ] Offline support
- [ ] Data sync mechanisms
- [x] Resilience patterns
- [x] Performance optimization (core functionality)
- [x] Event monitoring
- [ ] Metrics collection
- [ ] Add update profile functionality when API supports it
- [ ] State persistence
- [ ] UI state restoration

## Next Steps
1. [x] Complete User Management feature
2. [x] Implement Note feature with resilience patterns
3. [x] Implement Task feature with resilience patterns
4. [ ] Complete Topic management functionality
5. [ ] Add metrics collection system
6. [ ] Complete API documentation with usage examples
7. [ ] Add state persistence

## Implementation Priority
1. [x] User Management (Authentication is prerequisite)
2. [x] Notes Feature (Core functionality)
3. [x] Tasks Feature (Additional functionality)
4. [ ] Topic Management (Organization functionality)
5. [ ] State Management (User experience)
6. [ ] Metrics Collection (Monitoring)

## Recent Achievements
1. Fixed task status update functionality
   - Made formatting methods public and static in TaskModel
   - Ensured proper formatting of status strings (especially "in_progress")
   - Fixed due date formatting to use ISO format with UTC timezone

2. Updated tests to match current task structure
   - Changed parameter names from title to content
   - Updated assertions to match new parameter structure
   - Fixed status parameter to use enum value instead of string

3. Completed core Task functionality
   - Implemented all CRUD operations
   - Added proper error handling
   - Implemented resilience patterns
   - Added comprehensive testing
