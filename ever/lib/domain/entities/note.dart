/// Represents a note in the system
class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Note &&
          id == other.id &&
          title == other.title &&
          content == other.content &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          userId == other.userId;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      content.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      userId.hashCode;
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
  notProcessed,
  pending,
  completed,
  failed,
}
