import 'dart:async';

import '../../core/events.dart';
import '../../entities/note.dart';
import '../../events/note_events.dart';
import '../../repositories/note_repository.dart';
import '../base_usecase.dart';

/// Parameters for creating a note
class CreateNoteParams {
  final String title;
  final String content;
  final String userId;

  const CreateNoteParams({
    required this.title,
    required this.content,
    required this.userId,
  });
}

/// Use case for creating a new note
class CreateNoteUseCase extends BaseUseCase<CreateNoteParams> {
  final NoteRepository _repository;
  final _events = StreamController<DomainEvent>.broadcast();
  bool _isCreating = false;

  CreateNoteUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  Future<void> execute(CreateNoteParams params) async {
    if (_isCreating) {
      throw StateError('Creation already in progress');
    }
    
    _isCreating = true;
    _events.add(OperationInProgress('create_note'));
    
    try {
      final note = Note(
        id: '', // Will be set by backend
        title: params.title,
        content: params.content,
        userId: params.userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await for (final createdNote in _repository.create(note)) {
        _events.add(NoteCreated(createdNote));
      }
      
      _events.add(const OperationSuccess('create_note'));
    } catch (e) {
      _events.add(OperationFailure('create_note', e.toString()));
      rethrow;
    } finally {
      _isCreating = false;
    }
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
} 