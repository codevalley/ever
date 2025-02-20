import '../../../domain/entities/note.dart';
import 'base.dart';

/// Formatter for note-related CLI output
class NoteFormatter extends BaseFormatter {
  String _formatShortDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Format a single note for display
  String formatNote(Note note) {
    final processingInfo = 'Processing Status: ${note.processingStatus.name}';
    
    // Build enrichment info if note is processed
    final enrichmentInfo = note.isProcessed && note.enrichmentData != null
        ? '''
Title: ${note.enrichmentData!['title'] ?? ''}
Formatted: ${note.enrichmentData!['formatted'] ?? ''}
Engine: ${note.enrichmentData!['model_name'] ?? 'unknown'} (${note.enrichmentData!['tokens_used'] ?? 0} tokens)'''
        : '';

    return '''
Created: ${_formatShortDate(note.createdAt)}${note.updatedAt != null ? '\nUpdated: ${_formatShortDate(note.updatedAt!)}' : ''}
Raw Text: ${note.content}
$processingInfo\n$enrichmentInfo''';
  }

  /// Format a list of notes for display
  String formatNoteList(List<Note> notes) {
    if (notes.isEmpty) {
      return 'No notes found.';
    }

    return notes.map((note) => formatNote(note)).join('\n---\n');
  }
}
