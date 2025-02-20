import 'dart:async';

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
}

/// Use case for updating an existing note
class UpdateNoteUseCase extends BaseUseCase<UpdateNoteParams> {
  final NoteRepository _repository;
  final _events = StreamController<DomainEvent>.broadcast();
  bool _isUpdating = false;

  UpdateNoteUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  Future<void> execute(UpdateNoteParams params) async {
    if (_isUpdating) {
      return;
    }
    
    _isUpdating = true;
    _events.add(OperationInProgress('update_note'));
    
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
        return;
      }

      if (existingNote == null) {
        _events.add(OperationFailure('update_note', 'Note not found'));
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
        }
        _events.add(const OperationSuccess('update_note'));
      } catch (e) {
        _events.add(OperationFailure('update_note', e.toString()));
      }
    } finally {
      _isUpdating = false;
    }
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
} 