# Reactive Architecture Guide

## Overview

This guide explains the reactive architecture implemented in the Ever app, including our approach to data handling, error recovery, and resilience patterns. The architecture follows reactive programming principles while incorporating enterprise-grade reliability patterns.

### Architecture Overview

```mermaid
graph TD
    UI[UI Layer] --> |Observes| R[Repository Layer]
    R --> |Transforms| DS[DataSource Layer]
    DS --> |Raw Access| API[API/Database]
    
    %% Event Flow
    DS --> |Events| R
    R --> |Events| UI
    
    %% Additional Components
    RC[RetryConfig] --> DS
    EH[Error Handler] --> DS
    CB[Circuit Breaker] -.-> DS
    
    classDef current fill:#f9f,stroke:#333,stroke-width:2px
    classDef planned fill:#bbf,stroke:#333,stroke-width:1px
    class CB planned
    class RC,EH current
```

## Core Concepts

### 1. Reactive Streams

Our architecture is built around reactive streams, providing:
- Non-blocking operations
- Push-based data flow
- Backpressure handling
- Error propagation
- Resource cleanup

```mermaid
sequenceDiagram
    participant C as Client
    participant R as Repository
    participant DS as DataSource
    participant API as API/DB
    
    C->>+R: stream = repository.read()
    R->>+DS: dataSource.read()
    DS->>+API: HTTP/DB Request
    
    API-->>-DS: Response
    DS-->>R: Event: InProgress
    R-->>C: Event: InProgress
    
    DS-->>-R: Stream<Data>
    R-->>R: Transform Data
    R-->>-C: Stream<Entity>
    
    Note over C,API: Events flow independently
```

### 2. Event-Driven Architecture

```mermaid
graph LR
    subgraph Operations
        OP[Operation] --> IP[InProgress]
        IP --> |Success| S[Success]
        IP --> |Error| F[Failure]
    end
    
    subgraph Retry Events
        RE[Retry] --> RA[RetryAttempt]
        RA --> |Success| RS[RetrySuccess]
        RA --> |Max Attempts| RE[RetryExhausted]
    end
    
    subgraph Monitoring
        S --> M[Metrics]
        F --> M
        RS --> M
        RE --> M
    end
```

## Layered Architecture

### 1. Data Sources

The lowest layer, responsible for:
- Raw data access (API, database)
- Error handling and recovery
- Event emission
- Resource management

```dart
abstract class BaseDataSource<T> {
  Stream<DomainEvent> get events;
  Future<void> initialize();
  void dispose();
  // CRUD operations
}
```

### 2. Repositories

Middle layer that:
- Transforms data between domain and data layers
- Manages caching strategies
- Handles complex operations
- Provides domain-specific operations

```dart
class UserRepositoryImpl implements UserRepository {
  final UserDataSource _dataSource;
  final _eventController = StreamController<DomainEvent>.broadcast();
  
  Stream<DomainEvent> get events => _eventController.stream;
  // Implementation
}
```

## Resilience Patterns

### 1. Retry with Exponential Backoff

```mermaid
stateDiagram-v2
    [*] --> Attempt1
    Attempt1 --> Success: Success
    Attempt1 --> Attempt2: Failure + Delay(1s)
    Attempt2 --> Success: Success
    Attempt2 --> Attempt3: Failure + Delay(2s)
    Attempt3 --> Success: Success
    Attempt3 --> Failed: Failure/Max Attempts
    Success --> [*]
    Failed --> [*]
    
    note right of Attempt1: First try
    note right of Attempt2: Exponential backoff
    note right of Attempt3: Max delay cap
```

### 2. Error Recovery Flow

```mermaid
flowchart TD
    E[Error Occurs] --> C{Classify Error}
    C -->|Transient| R[Retry Logic]
    C -->|Permanent| F[Fail Fast]
    C -->|System| S[System Recovery]
    
    R --> RC{Retry Count}
    RC -->|< Max| D[Delay]
    RC -->|>= Max| EX[Exhausted]
    
    D --> NA[Next Attempt]
    NA --> C
    
    F --> EH[Error Handler]
    EX --> EH
    S --> EH
    
    EH --> EV[Event Emission]
```

## Best Practices

### 1. Error Handling

1. **Classify Errors**:
   - Transient (network issues, timeouts)
   - Permanent (validation errors, not found)
   - System errors (configuration, initialization)

2. **Error Recovery**:
   - Retry transient errors
   - Fail fast on permanent errors
   - Proper error transformation between layers

### 2. Resource Management

1. **Initialization**:
   ```dart
   Future<void> initialize() async {
     // Setup resources
     // Load cached data
     // Initialize connections
   }
   ```

2. **Cleanup**:
   ```dart
   void dispose() {
     _eventController.close();
     // Release other resources
   }
   ```

### 3. Testing

1. **Unit Tests**:
   - Test retry logic
   - Verify event emission
   - Check error handling

2. **Integration Tests**:
   - End-to-end flows
   - Error scenarios
   - Recovery behavior

## References

1. Reactive Programming:
   - [ReactiveX](http://reactivex.io/)
   - [Reactive Streams](https://www.reactive-streams.org/)
   - [Reactive Manifesto](https://www.reactivemanifesto.org/)

2. Resilience Patterns:
   - [Martin Fowler - Circuit Breaker](https://martinfowler.com/bliki/CircuitBreaker.html)
   - [Microsoft - Retry Pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/retry)
   - [Implementing Retry Pattern in Dart](https://medium.com/flutter-community/implementing-retry-pattern-in-dart-flutter-84af66cdb56f)

3. Event-Driven Architecture:
   - [Martin Fowler - Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html)
   - [CQRS Pattern](https://docs.microsoft.com/en-us/azure/architecture/patterns/cqrs)

## Implementation Examples

### Complete Retry Implementation

```dart
/// Configuration
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffFactor;

  const RetryConfig({
    required this.maxAttempts,
    required this.initialDelay,
    required this.maxDelay,
    required this.backoffFactor,
  });

  Duration getDelayForAttempt(int attempt) {
    if (attempt <= 0) return Duration.zero;
    final exponentialDelay = initialDelay * (backoffFactor * (attempt - 1));
    return exponentialDelay > maxDelay ? maxDelay : exponentialDelay;
  }
}

/// Usage in DataSource
class UserDataSourceImpl implements UserDataSource {
  final RetryConfig _retryConfig;
  
  Future<T> _executeWithRetry<T>(
    String operation,
    Future<T> Function() apiCall,
  ) async {
    int attempts = 0;
    while (true) {
      try {
        attempts++;
        return await apiCall();
      } catch (error) {
        if (!_shouldRetry(error) || attempts >= _retryConfig.maxAttempts) {
          rethrow;
        }
        final delay = _retryConfig.getDelayForAttempt(attempts);
        await Future.delayed(delay);
      }
    }
  }
}
```

### Event Handling Example

```dart
class UserRepositoryImpl implements UserRepository {
  final _eventController = StreamController<DomainEvent>.broadcast();
  
  Stream<User> register(String username) async* {
    _eventController.add(OperationInProgress('register'));
    try {
      final user = await _dataSource.register(username).first;
      _eventController.add(OperationSuccess('register', user));
      yield user;
    } catch (e) {
      _eventController.add(OperationFailure('register', e));
      rethrow;
    }
  }
}
```

## Monitoring & Observability

The architecture provides rich telemetry through events:

1. **Operation Metrics**:
   - Success/failure rates
   - Retry attempts
   - Operation durations
   - Error distributions

2. **Health Monitoring**:
   - Resource usage
   - Connection states
   - Cache hit rates
   - Error patterns

3. **Debugging**:
   - Operation traces
   - Error contexts
   - State transitions
   - Recovery attempts

## Future Improvements

1. **Circuit Breaker Pattern**:
   - Prevent cascade failures
   - Automatic service degradation
   - Self-healing capabilities

2. **Caching Strategies**:
   - Improved cache invalidation
   - Cache warming
   - Partial updates

3. **Metrics Collection**:
   - Centralized monitoring
   - Performance analytics
   - Error trending 