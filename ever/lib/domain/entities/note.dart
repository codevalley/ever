/// Represents a note in the system
class Note {
  /// Raw content of the note
  final String content;
  
  /// Display content of the note
  /// Returns formatted content if processing is complete, otherwise raw content
  String get displayContent =>
      processingStatus == ProcessingStatus.completed &&
              enrichmentData?['formatted'] != null
          ? enrichmentData!['formatted']
          : content;

  /// Display title of the note
  /// Returns enriched title if processing is complete, otherwise empty string
  String get displayTitle =>
      processingStatus == ProcessingStatus.completed &&
              enrichmentData?['title'] != null
          ? enrichmentData!['title']
          : '';

  /// Whether the note has been fully processed
  bool get isProcessed => processingStatus == ProcessingStatus.completed;

  /// Whether the note has any attachments
  bool get hasAttachments => attachments.isNotEmpty;


  final String id;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final String userId;
  final Map<String, dynamic>? enrichmentData;
  final ProcessingStatus processingStatus;
  final DateTime? processedAt;
  final List<Attachment> attachments;

  const Note({
    required this.id,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    required this.userId,
    this.enrichmentData,
    required this.processingStatus,
    this.processedAt,
    this.attachments = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          id == other.id &&
          content == other.content &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          userId == other.userId &&
          processingStatus == other.processingStatus &&
          processedAt == other.processedAt &&
          attachments == other.attachments;

  @override
  int get hashCode =>
      id.hashCode ^
      content.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      userId.hashCode ^
      processingStatus.hashCode ^
      processedAt.hashCode ^
      attachments.hashCode;
}

/// Represents an attachment to a note
class Attachment {
  final String type;
  final String url;

  const Attachment({
    required this.type,
    required this.url,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Attachment &&
          type == other.type &&
          url == other.url;

  @override
  int get hashCode => type.hashCode ^ url.hashCode;
}

/// Status of note processing
enum ProcessingStatus {
  pending,
  completed,
  failed,
}
