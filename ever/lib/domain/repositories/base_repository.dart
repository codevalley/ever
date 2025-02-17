import 'dart:async';
import '../core/events.dart';

/// Base interface for all repositories
/// All operations return Streams to maintain reactive pattern consistency
abstract class BaseRepository<T> {
  /// Stream of domain events from this repository
  Stream<DomainEvent> get events;

  /// Create a new entity
  /// Returns a Stream of the created entity
  Stream<T> create(T entity);

  /// Read an entity by ID
  /// Returns a Stream of the retrieved entity
  Stream<T> read(String id);

  /// Update an existing entity
  /// Returns a Stream of the updated entity
  Stream<T> update(T entity);

  /// Delete an entity by ID
  /// Returns a Stream that completes when deletion is done
  Stream<void> delete(String id);

  /// List all entities with optional filtering
  /// Returns a Stream of entity lists
  Stream<List<T>> list({Map<String, dynamic>? filters});

  /// Dispose of any resources
  void dispose();
}
