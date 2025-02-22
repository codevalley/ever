import '../core/events.dart';
import '../entities/note.dart';
import 'base_ds.dart';

/// Interface for note data source operations
abstract class NoteDataSource extends BaseDataSource<Note> {
  /// Stream of domain events emitted by this data source
  @override
  Stream<DomainEvent> get events;
  
  /// Creates a new note
  @override
  Stream<Note> create(Note note);

  /// Updates an existing note
  @override
  Stream<Note> update(Note note);

  /// Deletes a note by ID
  @override
  Stream<void> delete(String id);

  /// Lists notes with optional filters
  @override
  Stream<List<Note>> list({Map<String, dynamic>? filters});

  /// Reads a note by ID
  @override
  Stream<Note> read(String id);

  /// Search notes by content
  Future<List<Note>> search(String query);
  
  /// Process note content and update enrichment data
  Future<Note> process(String noteId);
  
  /// Add attachment to note
  Future<Note> addAttachment(String noteId, Attachment attachment);
  
  /// Initializes the data source
  @override
  Future<void> initialize();

  /// Disposes of any resources
  @override
  void dispose();
}
