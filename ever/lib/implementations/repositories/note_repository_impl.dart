import 'dart:async';

import '../../core/logging.dart';
import '../../domain/core/circuit_breaker.dart';
import '../../domain/core/events.dart';
import '../../domain/core/retry_config.dart';
import '../../domain/core/retry_events.dart';
import '../../domain/datasources/note_ds.dart';
import '../../domain/entities/note.dart';
import '../../domain/repositories/note_repository.dart';

/// Implementation of NoteRepository with resilience patterns
class NoteRepositoryImpl implements NoteRepository {
  final NoteDataSource _dataSource;
  final CircuitBreaker _circuitBreaker;
  final RetryConfig _retryConfig;
  final _eventController = StreamController<DomainEvent>.broadcast();
  StreamSubscription? _dataSourceSubscription;

  NoteRepositoryImpl(
    this._dataSource, {
    CircuitBreaker? circuitBreaker,
    RetryConfig? retryConfig,
  })  : _circuitBreaker = circuitBreaker ?? CircuitBreaker(),
        _retryConfig = retryConfig ?? RetryConfig.defaultConfig {
    _dataSourceSubscription = _dataSource.events.listen(_handleDataSourceEvent);
  }

  /// Handle events from the data source
  void _handleDataSourceEvent(DomainEvent event) {
    // Transform or forward events as needed
    if (event is OperationInProgress ||
        event is OperationSuccess ||
        event is OperationFailure ||
        event is RetryAttempt ||
        event is RetrySuccess ||
        event is RetryExhausted) {
      _eventController.add(event);
    } else {
      // Forward domain events directly
      _eventController.add(event);
    }
  }

  /// Execute operation with retry and circuit breaker
  Future<T> _executeWithResilience<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      return await _circuitBreaker.execute(() async {
        var attempts = 0;
        while (true) {
          try {
            attempts++;
            return await action();
          } catch (error) {
            if (!_retryConfig.shouldRetry(error) || attempts >= _retryConfig.maxAttempts) {
              rethrow;
            }
            _eventController.add(RetryAttempt(operation, attempts, _retryConfig.getDelayForAttempt(attempts), error));
            await Future.delayed(_retryConfig.getDelayForAttempt(attempts));
          }
        }
      });
    } on CircuitBreakerException catch (e) {
      _eventController.add(OperationFailure(
        operation,
        'Service temporarily unavailable: ${e.message}',
      ));
      rethrow;
    } catch (e) {
      _eventController.add(OperationFailure(operation, e.toString()));
      rethrow;
    }
  }

  @override
  Stream<DomainEvent> get events => _eventController.stream;

  @override
  Future<void> initialize() async {
    await _dataSource.initialize();
  }

  @override
  void dispose() {
    _dataSourceSubscription?.cancel();
    _circuitBreaker.dispose();
    _eventController.close();
    _dataSource.dispose();
  }

  @override
  Stream<Note> create(Note note) async* {
    try {
      await for (final createdNote in Stream.fromFuture(_executeWithResilience(
        'create_note',
        () async {
          await for (final note in _dataSource.create(note)) {
            return note;
          }
          throw Exception('No note received from data source');
        },
      ))) {
        yield createdNote;
      }
    } catch (e) {
      eprint('Failed to create note: $e', '❌');
      rethrow;
    }
  }

  @override
  Stream<Note> update(Note note) async* {
    try {
      await for (final updatedNote in Stream.fromFuture(_executeWithResilience(
        'update_note',
        () async {
          await for (final note in _dataSource.update(note)) {
            return note;
          }
          throw Exception('No note received from data source');
        },
      ))) {
        yield updatedNote;
      }
    } catch (e) {
      eprint('Failed to update note: $e', '❌');
      rethrow;
    }
  }

  @override
  Stream<void> delete(String id) {
    try {
      return _dataSource.delete(id);
    } catch (e) {
      eprint('Failed to delete note: $e', '❌');
      rethrow;
    }
  }

  @override
  Stream<List<Note>> list({Map<String, dynamic>? filters}) async* {
    try {
      await for (final notes in Stream.fromFuture(_executeWithResilience(
        'list_notes',
        () async {
          await for (final notes in _dataSource.list(filters: filters)) {
            return notes;
          }
          throw Exception('No notes received from data source');
        },
      ))) {
        yield notes;
      }
    } catch (e) {
      eprint('Failed to list notes: $e', '❌');
      rethrow;
    }
  }

  @override
  Stream<Note> read(String id) async* {
    try {
      await for (final note in Stream.fromFuture(_executeWithResilience(
        'read_note',
        () async {
          await for (final note in _dataSource.read(id)) {
            return note;
          }
          throw Exception('No note received from data source');
        },
      ))) {
        yield note;
      }
    } catch (e) {
      eprint('Failed to read note: $e', '❌');
      rethrow;
    }
  }

  @override
  Future<List<Note>> search(String query) async {
    try {
      return await _executeWithResilience(
        'search_notes',
        () => _dataSource.search(query),
      );
    } catch (e) {
      eprint('Failed to search notes: $e', '❌');
      rethrow;
    }
  }

  @override
  Future<Note> process(String noteId) async {
    try {
      return await _executeWithResilience(
        'process_note',
        () => _dataSource.process(noteId),
      );
    } catch (e) {
      eprint('Failed to process note: $e', '❌');
      rethrow;
    }
  }

  @override
  Future<Note> addAttachment(String noteId, Attachment attachment) async {
    try {
      return await _executeWithResilience(
        'add_attachment',
        () => _dataSource.addAttachment(noteId, attachment),
      );
    } catch (e) {
      eprint('Failed to add attachment: $e', '❌');
      rethrow;
    }
  }
} 