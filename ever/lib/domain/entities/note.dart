/// Represents a note in the system
class Note {
  final String id;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String userId;
  final Map<String, dynamic>? enrichmentData;
  final ProcessingStatus processingStatus;
  final DateTime? processedAt;

  const Note({
    required this.id,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    required this.userId,
    this.enrichmentData,
    required this.processingStatus,
    this.processedAt,
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
          processedAt == other.processedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      content.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      userId.hashCode ^
      processingStatus.hashCode ^
      processedAt.hashCode;
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
