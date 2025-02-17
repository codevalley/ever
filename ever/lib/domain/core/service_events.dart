import 'events.dart';

/// Event emitted when service is degraded
class ServiceDegraded extends DomainEvent {
  final DateTime timestamp;
  
  const ServiceDegraded(this.timestamp);
}

/// Event emitted when service is restored
class ServiceRestored extends DomainEvent {
  final DateTime timestamp;
  
  const ServiceRestored(this.timestamp);
}

/// Event emitted when service is recovered
class ServiceRecovered extends DomainEvent {
  final DateTime timestamp;
  
  const ServiceRecovered(this.timestamp);
}

/// Event emitted when operation is rejected due to service state
class OperationRejected extends DomainEvent {
  final String reason;
  
  const OperationRejected(this.reason);
} 