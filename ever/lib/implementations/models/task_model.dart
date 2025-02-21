import '../../domain/entities/task.dart';

/// Model class for Task with JSON serialization support
class TaskModel {
  final String id;
  final String content;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final List<String> tags;
  final String? parentId;
  final String? topicId;
  final ProcessingStatus processingStatus;
  final Map<String, dynamic> enrichmentData;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TaskModel({
    required this.id,
    required this.content,
    required this.status,
    required this.priority,
    this.dueDate,
    this.tags = const [],
    this.parentId,
    this.topicId,
    this.processingStatus = ProcessingStatus.pending,
    this.enrichmentData = const {},
    this.createdAt,
    this.updatedAt,
  });

  /// Create a model for task creation (without ID and timestamps)
  factory TaskModel.forCreation({
    required String content,
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    List<String> tags = const [],
    String? parentId,
    String? topicId,
  }) {
    return TaskModel(
      id: '', // Will be set by backend
      content: content,
      status: status,
      priority: priority,
      dueDate: dueDate,
      tags: tags,
      parentId: parentId,
      topicId: topicId,
    );
  }

  /// Create a model from JSON data
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'].toString(),
      content: json['content'] as String,
      status: _parseStatus(json['status'] as String?),
      priority: _parsePriority(json['priority'] as String?),
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      parentId: json['parent_id']?.toString(),
      topicId: json['topic_id']?.toString(),
      processingStatus: _parseProcessingStatus(json['processing_status'] as String?),
      enrichmentData: json['enrichment_data'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  /// Convert model to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      'tags': tags,
      if (parentId != null) 'parent_id': parentId,
      if (topicId != null) 'topic_id': topicId,
      'processing_status': processingStatus.toString().split('.').last,
      'enrichment_data': enrichmentData,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Convert model to domain entity
  Task toDomain() {
    return Task(
      id: id,
      content: content,
      status: status,
      priority: priority,
      dueDate: dueDate,
      tags: tags,
      parentId: parentId,
      topicId: topicId,
    );
  }

  /// Parse task status from string
  static TaskStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'done':
        return TaskStatus.done;
      case 'todo':
      default:
        return TaskStatus.todo;
    }
  }

  /// Parse task priority from string
  static TaskPriority _parsePriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return TaskPriority.high;
      case 'low':
        return TaskPriority.low;
      case 'medium':
      default:
        return TaskPriority.medium;
    }
  }

  /// Parse processing status from string
  static ProcessingStatus _parseProcessingStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return ProcessingStatus.completed;
      case 'failed':
        return ProcessingStatus.failed;
      case 'pending':
      default:
        return ProcessingStatus.pending;
    }
  }
} 