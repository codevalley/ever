import 'dart:async';
import '../core/events.dart';

/// Base interface for all data sources
abstract class BaseDataSource<T> {
  /// Stream of domain events from this data source
  Stream<DomainEvent> get events;

  /// Create a new entity
  void create(T entity);

  /// Read an entity by ID
  void read(String id);

  /// Update an existing entity
  void update(T entity);

  /// Delete an entity by ID
  void delete(String id);

  /// List all entities with optional filtering
  void list({Map<String, dynamic>? filters});

  /// Dispose of any resources
  void dispose();
}
