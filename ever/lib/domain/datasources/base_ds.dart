import 'dart:async';
import '../core/events.dart';

/// Base interface for all data sources
/// All operations are reactive and return Streams
abstract class BaseDataSource<T> {
  /// Stream of domain events from this data source
  Stream<DomainEvent> get events;

  /// Create a new entity
  /// Returns a Stream that emits the created entity
  /// Throws UnsupportedError if operation is not supported
  Stream<T> create(T entity);

  /// Read an entity by ID
  /// Returns a Stream that emits the retrieved entity
  /// Throws UnsupportedError if operation is not supported
  Stream<T> read(String id);

  /// Update an existing entity
  /// Returns a Stream that emits the updated entity
  /// Throws UnsupportedError if operation is not supported
  Stream<T> update(T entity);

  /// Delete an entity by ID
  /// Returns a Stream that completes when deletion is done
  /// Throws UnsupportedError if operation is not supported
  Stream<void> delete(String id);

  /// List all entities with optional filtering
  /// Returns a Stream that emits the list of entities
  /// Throws UnsupportedError if operation is not supported
  Stream<List<T>> list({Map<String, dynamic>? filters});

  /// Initialize the data source
  /// This should be called before using the data source
  /// Returns a Future that completes when initialization is done
  Future<void> initialize();

  /// Check if an operation is supported by this data source
  /// [operation]: The operation to check ('create', 'read', 'update', 'delete', 'list')
  bool isOperationSupported(String operation);

  /// Dispose of any resources
  /// This should be called when the data source is no longer needed
  void dispose();
}
