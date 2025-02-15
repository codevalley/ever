import '../entities/note.dart';
import 'base_ds.dart';

/// Data source interface for Note operations
abstract class NoteDataSource extends BaseDataSource<Note> {
  /// Search notes by content
  Future<List<Note>> search(String query);
  
  /// Process note content and update enrichment data
  Future<Note> process(String noteId);
  
  /// Add attachment to note
  Future<Note> addAttachment(String noteId, Attachment attachment);
}
