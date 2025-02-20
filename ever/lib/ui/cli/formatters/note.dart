import '../../../domain/entities/note.dart';
import 'base.dart';

/// Formatter for note-related CLI output
class NoteFormatter extends BaseFormatter {
  /// Format a single note for display
  String formatNote(Note note) {
    final enrichmentInfo = note.enrichmentData?.isNotEmpty == true
        ? '\nEnrichment Data:\n${note.enrichmentData!.entries.map((e) => '  ${e.key}: ${e.value}').join('\n')}'
        : '';

    final processingInfo = '\nProcessing Status: ${note.processingStatus.name}${note.processedAt != null ? ' (${formatDateTime(note.processedAt!)})' : ''}';

    return '''
Content: ${note.content}
Created: ${formatDateTime(note.createdAt)}${note.updatedAt != null ? '\nUpdated: ${formatDateTime(note.updatedAt!)}' : ''}$processingInfo$enrichmentInfo
''';
  }

  /// Format a list of notes for display
  String formatNoteList(List<Note> notes) {
    if (notes.isEmpty) {
      return 'No notes found.';
    }

    return notes.map((note) => formatNote(note)).join('\n---\n');
  }
} 