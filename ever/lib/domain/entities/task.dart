/// Represents a task in the system
class Task {
  final String id;
  final String content;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final List<String> tags;
  final String? parentId;
  final String? topicId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final ProcessingStatus processingStatus;

  const Task({
    required this.id,
    required this.content,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.tags = const [],
    this.parentId,
    this.topicId,
    this.createdAt,
    this.updatedAt,
    this.processingStatus = ProcessingStatus.pending,
  });
}

/// Status of a task
enum TaskStatus {
  todo,
  inProgress,
  done,
}

/// Priority of a task
enum TaskPriority {
  low,
  medium,
  high,
}

/// Processing status of a task
enum ProcessingStatus {
  pending,
  completed,
  failed,
}
