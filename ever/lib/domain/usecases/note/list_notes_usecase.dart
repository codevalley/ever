import 'dart:async';

import '../../core/events.dart';
import '../../events/note_events.dart';
import '../../repositories/note_repository.dart';
import '../base_usecase.dart';

/// Parameters for listing notes
class ListNotesParams {
  final Map<String, dynamic>? filters;

  const ListNotesParams({this.filters});
}

/// Use case for listing notes
class ListNotesUseCase extends BaseUseCase<void> {
  final NoteRepository _repository;
  final _events = StreamController<DomainEvent>.broadcast();
  bool _isListing = false;

  ListNotesUseCase(this._repository);

  @override
  Stream<DomainEvent> get events => _events.stream;

  @override
  Future<void> execute([void params]) async {
    if (_isListing) {
      return;
    }
    
    _isListing = true;
    _events.add(OperationInProgress('list_notes'));
    
    try {
      await for (final notes in _repository.list()) {
        _events.add(NotesRetrieved(notes));
      }
      
      _events.add(const OperationSuccess('list_notes'));
    } catch (e) {
      _events.add(OperationFailure('list_notes', e.toString()));
    } finally {
      _isListing = false;
    }
  }

  @override
  Future<void> dispose() async {
    await _events.close();
  }
} 