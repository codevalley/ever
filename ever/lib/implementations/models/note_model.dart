import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/note.dart';
part 'note_model.g.dart';

/// Model class for Note data from API
@JsonSerializable()
class NoteModel {
  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'content')
  final String content;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at', required: false)
  final DateTime? updatedAt;

  @JsonKey(name: 'user_id')
  final String userId;

  @JsonKey(
    name: 'attachments',
    defaultValue: <AttachmentModel>[],
    toJson: _attachmentsToJson,
  )
  final List<AttachmentModel> attachments;

  @JsonKey(
    name: 'processing_status',
    defaultValue: ProcessingStatus.pending,
  )
  final ProcessingStatus processingStatus;

  @JsonKey(name: 'enrichment_data', required: false)
  final Map<String, dynamic>? enrichmentData;

  @JsonKey(name: 'processed_at', required: false)
  final DateTime? processedAt;

  const NoteModel({
    required this.id,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    required this.userId,
    required this.attachments,
    required this.processingStatus,
    this.enrichmentData,
    this.processedAt,
  });

  /// Create model from API JSON
  factory NoteModel.fromJson(Map<String, dynamic> json) =>
      _$NoteModelFromJson(json);

  /// Convert model to JSON for API
  Map<String, dynamic> toJson() => _$NoteModelToJson(this);

  /// Helper method to convert attachments to JSON
  static List<Map<String, dynamic>> _attachmentsToJson(List<AttachmentModel> attachments) {
    return attachments.map((a) => a.toJson()).toList();
  }

  /// Convert to domain entity
  Note toDomain() {
    return Note(
      id: id.toString(),
      content: content,
      userId: userId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      enrichmentData: enrichmentData,
      processingStatus: processingStatus,
      processedAt: processedAt,
    );
  }

  /// Create a new note model for API creation
  factory NoteModel.forCreation({
    required String content,
    required String userId,
  }) {
    final now = DateTime.now();
    return NoteModel(
      id: 0, // Will be set by backend
      content: content,
      userId: userId,
      createdAt: now,
      updatedAt: now,
      attachments: [],
      processingStatus: ProcessingStatus.pending,
    );
  }
}

/// Model class for Note Attachment data
@JsonSerializable()
class AttachmentModel {
  @JsonKey(name: 'type')
  final String type;

  @JsonKey(name: 'url')
  final String url;

  const AttachmentModel({
    required this.type,
    required this.url,
  });

  /// Create model from API JSON
  factory AttachmentModel.fromJson(Map<String, dynamic> json) =>
      _$AttachmentModelFromJson(json);

  /// Convert model to JSON for API
  Map<String, dynamic> toJson() => _$AttachmentModelToJson(this);

  /// Convert to domain entity
  Attachment toDomain() {
    return Attachment(
      type: type,
      url: url,
    );
  }
} 