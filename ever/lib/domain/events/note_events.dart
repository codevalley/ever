import '../core/events.dart';
import '../entities/note.dart';

/// Event emitted when a note is created
class NoteCreated extends DomainEvent {
  final Note note;
  const NoteCreated(this.note);
}

/// Event emitted when a note is updated
class NoteUpdated extends DomainEvent {
  final Note note;
  const NoteUpdated(this.note);
}

/// Event emitted when a note is deleted
class NoteDeleted extends DomainEvent {
  final String noteId;
  const NoteDeleted(this.noteId);
}

/// Event emitted when notes are retrieved
class NotesRetrieved extends DomainEvent {
  final List<Note> notes;
  const NotesRetrieved(this.notes);
}

/// Event emitted when a single note is retrieved
class NoteRetrieved extends DomainEvent {
  final Note note;
  const NoteRetrieved(this.note);
}

/// Event emitted when note processing starts
class NoteProcessingStarted extends DomainEvent {
  final String noteId;
  const NoteProcessingStarted(this.noteId);
}

/// Event emitted when note processing completes
class NoteProcessingCompleted extends DomainEvent {
  final Note note;
  const NoteProcessingCompleted(this.note);
}

/// Event emitted when note processing fails
class NoteProcessingFailed extends DomainEvent {
  final String noteId;
  final String error;
  const NoteProcessingFailed(this.noteId, this.error);
} 