/// Represents a note in the system
class Note {
  final String id;
  final String content;
  final Attachment? attachment;
  final ProcessingStatus processingStatus;
  final Map<String, dynamic> enrichmentData;

  const Note({
    required this.id,
    required this.content,
    this.attachment,
    this.processingStatus = ProcessingStatus.notProcessed,
    this.enrichmentData = const {},
  });
}

/// Represents an attachment to a note
class Attachment {
  final String type;
  final String url;

  const Attachment({
    required this.type,
    required this.url,
  });
}

/// Status of note processing
enum ProcessingStatus {
  notProcessed,
  pending,
  completed,
  failed,
}
