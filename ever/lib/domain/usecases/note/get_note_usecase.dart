import 'dart:async';

import 'package:rxdart/rxdart.dart';
import '../../core/events.dart';
import '../../events/note_events.dart';
import '../../entities/note.dart';
import '../../repositories/note_repository.dart';
import '../base_usecase.dart';

/// Parameters for getting a note
class GetNoteParams {
  final String id;

  const GetNoteParams({required this.id});

  bool validate() {
    return id.isNotEmpty;
  }

  String? validateWithMessage() {
    if (id.isEmpty) {
      return 'Note ID cannot be empty';
    }
    return null;
  }
}

/// Use case for getting a single note by ID
/// 
/// Flow:
/// 1. Validates the note ID
/// 2. Calls repository to get note with retries
/// 3. Emits appropriate events:
///    - [OperationInProgress]: When retrieval starts
///    - [NoteRetrieved]: When note is retrieved successfully
///    - [OperationSuccess]: When retrieval completes successfully
///    - [OperationFailure]: When retrieval fails
class GetNoteUseCase extends BaseUseCase<GetNoteParams> {
  final NoteRepository _repository;
  final _events = BehaviorSubject<DomainEvent>();
  final _noteController = StreamController<Note>.broadcast();
  StreamSubscription<Note>? _getNoteSubscription;
  bool _isExecuting = false;
  int _retryCount = 0;
  static const _maxRetries = 3;

  GetNoteUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  /// Stream of the note
  Stream<Note> get note => _noteController.stream;

  @override
  Future<void> execute([GetNoteParams? params]) async {
    if (_isExecuting) return;
    if (params == null) {
      _events.add(OperationFailure('get_note', 'Note ID is required'));
      return;
    }

    _isExecuting = true;
    _events.add(OperationInProgress('get_note'));

    final validationError = params.validateWithMessage();
    if (validationError != null) {
      _events.add(OperationFailure('get_note', validationError));
      _isExecuting = false;
      return;
    }

    try {
      await _getNoteSubscription?.cancel();
      _getNoteSubscription = _repository.read(params.id)
        .listen(
          (note) {
            _noteController.add(note);
            _events.add(NoteRetrieved(note));
            _events.add(const OperationSuccess('get_note'));
            _isExecuting = false;
            _retryCount = 0;
          },
          onError: (error) async {
            if (_retryCount < _maxRetries && _shouldRetry(error)) {
              _retryCount++;
              await execute(params);
            } else {
              _events.add(OperationFailure('get_note', error.toString()));
              _isExecuting = false;
              _retryCount = 0;
              _noteController.addError(error);
            }
          },
          onDone: () {
            _isExecuting = false;
          },
          cancelOnError: true,
        );
    } catch (e) {
      _events.add(OperationFailure('get_note', e.toString()));
      _isExecuting = false;
      _noteController.addError(e);
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
    await _getNoteSubscription?.cancel();
    await _events.close();
    await _noteController.close();
  }
} 