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
    
    %% Resilience Patterns
    RC[RetryConfig] --> DS
    CB[CircuitBreaker] --> DS
    
    %% Monitoring
    M[Metrics] --> |Collects| DS
    M --> |Aggregates| R
    
    classDef implemented fill:#9f9,stroke:#333,stroke-width:2px
    classDef planned fill:#bbf,stroke:#333,stroke-width:1px
    class RC,CB implemented
    class M planned
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
    
    subgraph Resilience Events
        RE[Retry] --> RA[RetryAttempt]
        RA --> |Success| RS[RetrySuccess]
        RA --> |Max Attempts| RE[RetryExhausted]
        
        CB[CircuitBreaker] --> Open
        CB --> HalfOpen
        CB --> Closed
    end
    
    subgraph Monitoring
        S --> M[Metrics]
        F --> M
        RS --> M
        RE --> M
        CB --> M
    end
```

## Resilience Patterns

### 1. Retry with Exponential Backoff

The retry mechanism provides automatic retry of failed operations with exponential backoff:

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
```

#### Configuration

```dart
class RetryConfig {
  final int maxAttempts;        // Maximum retry attempts
  final Duration initialDelay;   // Initial delay before first retry
  final Duration maxDelay;       // Maximum delay between retries
  final double backoffFactor;    // Multiplier for each subsequent retry
}
```

Default configuration:
- `maxAttempts`: 3
- `initialDelay`: 1 second
- `maxDelay`: 10 seconds
- `backoffFactor`: 2.0

#### Events

The retry mechanism emits the following events:
- `RetryAttempt`: When a retry is about to be attempted
- `RetrySuccess`: When an operation succeeds after retries
- `RetryExhausted`: When all retry attempts are exhausted

### 2. Circuit Breaker Pattern

The circuit breaker prevents cascade failures and provides automatic service degradation:

```mermaid
stateDiagram-v2
    [*] --> Closed
    Closed --> Open: Failure Threshold Reached
    Open --> HalfOpen: Reset Timeout Elapsed
    HalfOpen --> Closed: Successful Trial Calls
    HalfOpen --> Open: Any Failure
```

#### States

1. **Closed** (Normal Operation):
   - All calls proceed normally
   - Failures are counted
   - Transitions to Open if failure threshold is reached

2. **Open** (Service Degraded):
   - All calls are rejected immediately
   - Automatic transition to Half-Open after reset timeout
   - Prevents cascade failures

3. **Half-Open** (Recovery Mode):
   - Limited number of trial calls allowed
   - Success transitions to Closed after max attempts
   - Any failure transitions back to Open
   - Prevents premature recovery

#### Configuration

```dart
class CircuitBreakerConfig {
  final int failureThreshold;     // Failures before opening
  final Duration resetTimeout;     // Time before recovery attempt
  final int halfOpenMaxAttempts;  // Trial calls allowed
}
```

Default configuration:
- `failureThreshold`: 5
- `resetTimeout`: 30 seconds
- `halfOpenMaxAttempts`: 3

#### Events

The circuit breaker emits the following events:
- `transition_to_open`: Service is degraded
- `transition_to_half_open`: Recovery is being attempted
- `transition_to_closed`: Service is restored
- `operation_rejected`: Call was rejected

## Implementation Examples

### 1. Using Retry Mechanism

```dart
// Configure retry behavior
final retryConfig = RetryConfig(
  maxAttempts: 3,
  initialDelay: Duration(seconds: 1),
  maxDelay: Duration(seconds: 10),
  backoffFactor: 2.0,
);

// Execute with retry
Stream<T> _executeWithRetry<T>(
  String operation,
  Future<T> Function() apiCall,
) async* {
  int attempts = 0;
  while (attempts < retryConfig.maxAttempts) {
    try {
      attempts++;
      final result = await apiCall();
      yield result;
      return;
    } catch (error) {
      if (!_isRetryable(error) || 
          attempts >= retryConfig.maxAttempts) {
        rethrow;
      }
      final delay = retryConfig.getDelayForAttempt(attempts);
      await Future.delayed(delay);
    }
  }
}
```

### 2. Using Circuit Breaker

```dart
// Configure circuit breaker
final circuitBreaker = CircuitBreaker(
  CircuitBreakerConfig(
    failureThreshold: 5,
    resetTimeout: Duration(seconds: 30),
    halfOpenMaxAttempts: 3,
  )
);

// Execute through circuit breaker
Future<T> execute<T>(Future<T> Function() operation) async {
  // Circuit breaker will:
  // 1. Track failures in closed state
  // 2. Reject calls in open state
  // 3. Allow limited calls in half-open state
  // 4. Handle state transitions automatically
  return await circuitBreaker.execute(operation);
}
```

## Best Practices

### 1. Retry Configuration

1. **Identify Retryable Operations**:
   - Network timeouts
   - Rate limiting responses
   - Temporary service unavailability
   - Connection errors

2. **Configure Appropriate Delays**:
   - Start with small initial delays (1s)
   - Use reasonable backoff factors (2.0)
   - Cap maximum delays (10s)
   - Consider operation context

3. **Set Reasonable Attempt Limits**:
   - 3-5 attempts typically sufficient
   - Consider operation criticality
   - Account for total time impact

### 2. Circuit Breaker Configuration

1. **Failure Thresholds**:
   - Set based on traffic patterns
   - Consider error impact
   - Account for normal error rates
   - Start conservative (5-10)

2. **Reset Timeouts**:
   - Match service recovery patterns
   - Consider dependencies
   - Start with 30-60 seconds
   - Adjust based on monitoring

3. **Half-Open Attempts**:
   - Limited trial calls (2-3)
   - Prevent premature recovery
   - Consider service capacity
   - Monitor success rates

### 3. Monitoring

1. **Key Metrics**:
   - Retry attempts/success rates
   - Circuit breaker state changes
   - Operation latencies
   - Error distributions

2. **Alerts**:
   - Service degradation
   - High retry rates
   - Circuit breaker trips
   - Recovery failures

3. **Dashboards**:
   - Real-time state visualization
   - Historical patterns
   - Error trending
   - Performance impact

## Configuration Guidelines

### 1. Retry Configuration Guidelines

```dart
final retryConfig = RetryConfig(
  maxAttempts: 3,        // Start conservative
  initialDelay: Duration(seconds: 1),
  maxDelay: Duration(seconds: 10),
  backoffFactor: 2.0,
);
```

#### Key Considerations:
1. **Max Attempts**:
   - Start with 3-5 attempts for most operations
   - Consider operation criticality
   - Balance user experience vs server load
   - Example: Auth operations = 3, Data sync = 5

2. **Delay Strategy**:
   - Initial delay: 1 second (standard)
   - Max delay: 10 seconds (prevent long waits)
   - Backoff factor: 2.0 (standard exponential)
   - Example delays: 1s → 2s → 4s → 8s → 10s

3. **Operation Types**:
   ```dart
   // Network operations (more retries)
   final networkConfig = RetryConfig(
     maxAttempts: 5,
     initialDelay: Duration(seconds: 1),
     maxDelay: Duration(seconds: 10),
     backoffFactor: 2.0,
   );

   // User operations (fewer retries)
   final userConfig = RetryConfig(
     maxAttempts: 3,
     initialDelay: Duration(milliseconds: 500),
     maxDelay: Duration(seconds: 5),
     backoffFactor: 2.0,
   );
   ```

### 2. Circuit Breaker Configuration

```dart
final circuitConfig = CircuitBreakerConfig(
  failureThreshold: 5,    // Failures before opening
  resetTimeout: Duration(seconds: 30),
  halfOpenMaxAttempts: 3,
);
```

#### Key Considerations:
1. **Failure Threshold**:
   - Start with 5 failures
   - Consider traffic patterns
   - Account for normal error rates
   - Example: High traffic = 10, Low traffic = 5

2. **Reset Timeout**:
   - Match service recovery patterns
   - Consider dependencies
   - Default: 30-60 seconds
   - Example: Simple API = 30s, Complex service = 60s

3. **Half-Open State**:
   - Limited trial calls (2-3)
   - Prevent premature recovery
   - Consider service capacity
   - Example: 3 attempts for gradual recovery

## Event Handling

### 1. Event Types

```dart
// Operation Events
OperationInProgress
OperationSuccess
OperationFailure

// Retry Events
RetryAttempt
RetrySuccess
RetryExhausted

// Circuit Breaker Events
ServiceDegraded
ServiceRestored
OperationRejected

// Domain Events
UserRegistered
TokenObtained
TokenRefreshFailed
```

### 2. Event Flow

```mermaid
sequenceDiagram
    participant UI
    participant Repository
    participant DataSource
    participant Service

    Service->>DataSource: Operation Start
    DataSource->>Repository: OperationInProgress
    Repository->>UI: OperationInProgress

    alt Success Path
        Service-->>DataSource: Success Response
        DataSource->>Repository: OperationSuccess
        Repository->>UI: DomainEvent (e.g., UserRegistered)
    else Retry Path
        Service-->>DataSource: Failure
        DataSource->>Repository: RetryAttempt
        Repository->>UI: RetryAttempt
        DataSource->>Service: Retry Operation
    else Circuit Open
        Service-->>DataSource: Multiple Failures
        DataSource->>Repository: ServiceDegraded
        Repository->>UI: ServiceDegraded
    end
```

### 3. Event Handling Best Practices

1. **Event Transformation**:
   ```dart
   // Transform low-level events to domain events
   void _handleUserSuccess(User user) {
     if (user.userSecret != null) {
       _eventController.add(UserRegistered(user));
     } else {
       _eventController.add(CurrentUserRetrieved(user));
     }
   }
   ```

2. **Event Propagation**:
   ```dart
   // Listen to data source events
   _dataSource.events.listen((event) {
     if (event is OperationSuccess) {
       _handleSuccess(event.data);
     } else if (event is OperationFailure) {
       _handleFailure(event.error);
     } else {
       // Forward other events
       _eventController.add(event);
     }
   });
   ```

## Monitoring and Observability

### 1. Key Metrics

1. **Operation Metrics**:
   - Success/failure rates
   - Operation latency
   - Error distribution
   - Active operations

2. **Retry Metrics**:
   - Retry attempts per operation
   - Retry success rate
   - Average attempts before success
   - Retry exhaustion rate

3. **Circuit Breaker Metrics**:
   - Circuit state changes
   - Time in each state
   - Rejection rate
   - Recovery success rate

### 2. Monitoring Implementation

```dart
class MetricsCollector {
  // Operation metrics
  final _operationLatency = <String, Duration>{};
  final _operationCounts = <String, int>{};
  
  // Retry metrics
  final _retryAttempts = <String, int>{};
  final _retrySuccess = <String, int>{};
  
  // Circuit breaker metrics
  final _circuitStateChanges = <String, int>{};
  final _rejectionCount = <String, int>{};
  
  void recordOperation(String operation, Duration latency) {
    _operationLatency[operation] = latency;
    _operationCounts[operation] = 
      (_operationCounts[operation] ?? 0) + 1;
  }
  
  void recordRetry(String operation) {
    _retryAttempts[operation] = 
      (_retryAttempts[operation] ?? 0) + 1;
  }
  
  void recordCircuitStateChange(String newState) {
    _circuitStateChanges[newState] = 
      (_circuitStateChanges[newState] ?? 0) + 1;
  }
}
```

### 3. Alerting Guidelines

1. **Critical Alerts**:
   - Circuit breaker opens
   - High retry exhaustion rate
   - Persistent failures
   - Service degradation

2. **Warning Alerts**:
   - Increased retry attempts
   - Latency spikes
   - Error rate increase
   - Resource usage

3. **Alert Configuration**:
   ```dart
   class AlertConfig {
     final double errorRateThreshold;    // e.g., 0.1 (10%)
     final Duration latencyThreshold;    // e.g., 5 seconds
     final int retryExhaustionThreshold; // e.g., 10 per minute
     final Duration circuitOpenDuration; // e.g., 5 minutes
   }
   ```

## Testing Guidelines

### 1. Unit Testing Resilience Patterns

```dart
test('should retry on network error and succeed', () async {
  var attempts = 0;
  when(client.post(any))
    .thenAnswer((_) async {
      attempts++;
      if (attempts < 3) {
        throw NetworkException();
      }
      return successResponse;
    });

  final result = await operation.execute();
  expect(attempts, 3);
  expect(result, isNotNull);
});
```

### 2. Integration Testing

```dart
test('end-to-end flow with resilience', () async {
  // Setup test configurations
  final testRetryConfig = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(milliseconds: 10),
    maxDelay: Duration(milliseconds: 50),
    backoffFactor: 2.0,
  );

  // Test with intermittent failures
  final events = await repository
    .register(username)
    .map((event) => event.runtimeType)
    .toList();

  expect(events, containsAllInOrder([
    OperationInProgress,
    RetryAttempt,
    RetrySuccess,
    UserRegistered,
  ]));
});
```

### 3. Event Testing

```dart
test('should emit correct event sequence', () async {
  final events = [];
  repository.events.listen(events.add);

  // Trigger operation
  await repository.operation();

  expect(events, containsAllInOrder([
    isA<OperationInProgress>(),
    isA<RetryAttempt>(),
    isA<OperationSuccess>(),
  ]));
});
```

## Future Improvements

1. **Enhanced Monitoring**:
   - Centralized metrics collection
   - Real-time dashboards
   - Automated alerting
   - Pattern analysis

2. **Advanced Patterns**:
   - Bulkhead isolation
   - Rate limiting
   - Request caching
   - Load shedding

3. **Configuration Management**:
   - Dynamic thresholds
   - Pattern recognition
   - Automated tuning
   - A/B testing support 