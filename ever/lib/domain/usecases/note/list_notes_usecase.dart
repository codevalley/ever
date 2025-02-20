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
///    - [OperationInProgress]: When listing starts
///    - [NotesRetrieved]: When notes are retrieved successfully
///    - [OperationSuccess]: When listing completes successfully
///    - [OperationFailure]: When listing fails
class ListNotesUseCase extends BaseUseCase<ListNotesParams> {
  final NoteRepository _repository;
  final _events = BehaviorSubject<DomainEvent>();
  final _notesSubject = BehaviorSubject<List<Note>>();
  StreamSubscription<List<Note>>? _listSubscription;
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

    _events.add(OperationInProgress('list_notes'));

    final validationError = params?.validateWithMessage();
    if (validationError != null) {
      _events.add(OperationFailure('list_notes', validationError));
      _isExecuting = false;
      return;
    }

    try {
      await _listSubscription?.cancel();
      _listSubscription = _repository.list(filters: params?.filters)
        .listen(
          (notes) {
            _notesSubject.add(notes);
            _events.add(NotesRetrieved(notes));
            _events.add(const OperationSuccess('list_notes'));
            _isExecuting = false;
            _retryCount = 0;
          },
          onError: (error) async {
            if (_retryCount < _maxRetries && _shouldRetry(error)) {
              _retryCount++;
              await execute(params);
            } else {
              _events.add(OperationFailure('list_notes', error.toString()));
              _isExecuting = false;
              _retryCount = 0;
            }
          },
          onDone: () {
            _isExecuting = false;
          },
        );
    } catch (e) {
      _events.add(OperationFailure('list_notes', e.toString()));
      _isExecuting = false;
    }
  }

  bool _shouldRetry(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') || 
           errorStr.contains('timeout') || 
           errorStr.contains('connection');
  }

  @override
  Future<void> dispose() async {
    await _listSubscription?.cancel();
    await _events.close();
    await _notesSubject.close();
  }
} 