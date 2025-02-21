import 'dart:async';

import 'package:rxdart/rxdart.dart';
import '../../core/events.dart';
import '../../entities/note.dart';
import '../../events/note_events.dart';
import '../../repositories/note_repository.dart';
import '../base_usecase.dart';

/// Parameters for updating a note
class UpdateNoteParams {
  final String noteId;
  final String? content;

  const UpdateNoteParams({
    required this.noteId,
    this.content,
  });

  bool validate() {
    if (noteId.isEmpty) return false;
    if (content != null && content!.isEmpty) return false;
    return true;
  }

  String? validateWithMessage() {
    if (noteId.isEmpty) {
      return 'Note ID cannot be empty';
    }
    if (content != null && content!.isEmpty) {
      return 'Content cannot be empty if provided';
    }
    return null;
  }
}

/// Use case for updating an existing note
class UpdateNoteUseCase extends BaseUseCase<UpdateNoteParams> {
  final NoteRepository _repository;
  final _events = BehaviorSubject<DomainEvent>();
  bool _isUpdating = false;
  int _retryCount = 0;
  static const _maxRetries = 3;

  UpdateNoteUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  Future<void> execute(UpdateNoteParams params) async {
    if (_isUpdating) {
      return;
    }

    final validationError = params.validateWithMessage();
    if (validationError != null) {
      _events.add(OperationFailure('update_note', validationError));
      return;
    }
    
    _isUpdating = true;
    _retryCount = 0;
    _events.add(OperationInProgress('update_note'));
    
    while (true) {
      try {
        // First get the existing note
        Note? existingNote;
        try {
          await for (final note in _repository.read(params.noteId)) {
            existingNote = note;
            break;
          }
        } catch (e) {
          _events.add(OperationFailure('update_note', e.toString()));
          _isUpdating = false;
          return;
        }

        if (existingNote == null) {
          _events.add(OperationFailure('update_note', 'Note not found'));
          _isUpdating = false;
          return;
        }

        // Create updated note with new values
        final updatedNote = Note(
          id: params.noteId,
          content: params.content ?? existingNote.content,
          userId: existingNote.userId,
          createdAt: existingNote.createdAt,
          updatedAt: DateTime.now(),
          processingStatus: ProcessingStatus.pending,
        );

        // Update note and wait for completion
        try {
          await for (final note in _repository.update(updatedNote)) {
            _events.add(NoteUpdated(note));
            _events.add(const OperationSuccess('update_note'));
            _isUpdating = false;
            _retryCount = 0;
            return;
          }
        } catch (e) {
          if (_retryCount < _maxRetries && _shouldRetry(e)) {
            _retryCount++;
            _events.add(OperationInProgress('update_note'));
            await Future.delayed(Duration(milliseconds: 100 * _retryCount));
            continue;
          } else {
            _events.add(OperationFailure('update_note', e.toString()));
            _isUpdating = false;
            _retryCount = 0;
            return;
          }
        }
      } catch (e) {
        _events.add(OperationFailure('update_note', e.toString()));
        _isUpdating = false;
        _retryCount = 0;
        return;
      }
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
    await _events.close();
  }
} 