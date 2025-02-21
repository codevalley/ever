import '../core/events.dart';
import '../entities/task.dart';

/// Event emitted when a task is created
class TaskCreated extends DomainEvent {
  final Task task;
  const TaskCreated(this.task);
}

/// Event emitted when a task is updated
class TaskUpdated extends DomainEvent {
  final Task task;
  const TaskUpdated(this.task);
}

/// Event emitted when a task is deleted
class TaskDeleted extends DomainEvent {
  final String taskId;
  const TaskDeleted(this.taskId);
}

/// Event emitted when tasks are retrieved
class TasksRetrieved extends DomainEvent {
  final List<Task> tasks;
  const TasksRetrieved(this.tasks);
}

/// Event emitted when a task is retrieved
class TaskRetrieved extends DomainEvent {
  final Task task;
  const TaskRetrieved(this.task);
}

/// Event emitted when task processing starts
class TaskProcessingStarted extends DomainEvent {
  final String taskId;

  const TaskProcessingStarted(this.taskId);

  List<Object?> get props => [taskId];
}

/// Event emitted when task processing completes
class TaskProcessingCompleted extends DomainEvent {
  final Task task;

  const TaskProcessingCompleted(this.task);

  List<Object?> get props => [task];
}

/// Event emitted when task processing fails
class TaskProcessingFailed extends DomainEvent {
  final String taskId;
  final String error;

  const TaskProcessingFailed(this.taskId, this.error);

  List<Object?> get props => [taskId, error];
}

/// Event emitted when task status changes
class TaskStatusChanged extends DomainEvent {
  final String taskId;
  final TaskStatus status;

  const TaskStatusChanged(this.taskId, this.status);

  List<Object?> get props => [taskId, status];
}

/// Event emitted when task priority changes
class TaskPriorityChanged extends DomainEvent {
  final String taskId;
  final TaskPriority priority;

  const TaskPriorityChanged(this.taskId, this.priority);

  List<Object?> get props => [taskId, priority];
} 