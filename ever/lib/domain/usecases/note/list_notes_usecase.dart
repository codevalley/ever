import 'dart:async';

import 'package:rxdart/rxdart.dart';
import '../../core/events.dart';
import '../../events/note_events.dart';
import '../../entities/note.dart';
import '../../repositories/note_repository.dart';
import '../base_usecase.dart';

/// Parameters for listing notes
class ListNotesParams {
  final Map<String, dynamic>? filters;

  const ListNotesParams({this.filters});

  bool validate() {
    // Add any validation logic if needed
    return true;
  }

  String? validateWithMessage() {
    // Add any validation messages if needed
    return null;
  }
}

/// Use case for listing notes
/// 
/// Flow:
/// 1. Validates the filters if any
/// 2. Calls repository to list notes with retries
/// 3. Emits appropriate events:
///    - [OperationInProgress]: When listing starts and on each retry
///    - [NotesRetrieved]: When notes are retrieved successfully
///    - [OperationSuccess]: When listing completes successfully
///    - [OperationFailure]: When listing fails after all retries
class ListNotesUseCase extends BaseUseCase<ListNotesParams> {
  final NoteRepository _repository;
  final _events = BehaviorSubject<DomainEvent>();
  final _notesSubject = BehaviorSubject<List<Note>>();
  bool _isExecuting = false;
  int _retryCount = 0;
  static const _maxRetries = 3;

  ListNotesUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  /// Stream of notes
  Stream<List<Note>> get notes => _notesSubject.stream;

  @override
  Future<void> execute([ListNotesParams? params]) async {
    if (_isExecuting) return;
    _isExecuting = true;
    _retryCount = 0;

    // Initial attempt
    _events.add(OperationInProgress('list_notes'));

    while (true) {
      try {
        final notes = await _repository.list(filters: params?.filters).first;
        _notesSubject.add(notes);
        _events.add(NotesRetrieved(notes));
        _events.add(const OperationSuccess('list_notes'));
        break;
      } catch (e) {
        if (_retryCount < _maxRetries && _shouldRetry(e)) {
          _retryCount++;
          // Emit progress event for retry
          _events.add(OperationInProgress('list_notes'));
          await Future.delayed(Duration(milliseconds: 100 * _retryCount));
          continue;
        } else {
          _events.add(OperationFailure('list_notes', e.toString()));
          break;
        }
      }
    }

    _isExecuting = false;
    _retryCount = 0;
  }

  bool _shouldRetry(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') || 
           errorStr.contains('timeout') || 
           errorStr.contains('connection');
  }

  @override
  Future<void> dispose() async {
    await _events.close();
    await _notesSubject.close();
  }
} 