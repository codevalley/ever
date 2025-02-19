import 'dart:async';

import '../../core/events.dart';
import '../../events/note_events.dart';
import '../../repositories/note_repository.dart';
import '../base_usecase.dart';

/// Parameters for deleting a note
class DeleteNoteParams {
  final String noteId;

  const DeleteNoteParams({required this.noteId});
}

/// Use case for deleting a note
class DeleteNoteUseCase extends BaseUseCase<DeleteNoteParams> {
  final NoteRepository _repository;
  final _events = StreamController<DomainEvent>.broadcast();
  bool _isDeleting = false;

  DeleteNoteUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  Future<void> execute(DeleteNoteParams params) async {
    if (_isDeleting) {
      return;
    }
    
    _isDeleting = true;
    _events.add(OperationInProgress('delete_note'));
    
    try {
      await for (final _ in _repository.delete(params.noteId)) {
        _events.add(NoteDeleted(params.noteId));
      }
      
      _events.add(const OperationSuccess('delete_note'));
    } catch (e) {
      _events.add(OperationFailure('delete_note', e.toString()));
    } finally {
      _isDeleting = false;
    }
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
} 