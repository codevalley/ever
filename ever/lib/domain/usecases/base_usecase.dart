import 'dart:async';
import '../core/events.dart';

/// Base interface for all use cases
/// [P] is the parameter type
abstract class BaseUseCase<P> {
  /// Stream of domain events from this use case
  Stream<DomainEvent> get events;

  /// Execute the use case with given parameters
  void execute(P params);

  /// Dispose of any resources
  void dispose();
}

/// Use case that doesn't require any parameters
abstract class NoParamsUseCase extends BaseUseCase<void> {
  @override
  void execute([void params]);
}
