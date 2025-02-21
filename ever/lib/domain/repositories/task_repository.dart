import '../core/events.dart';
import '../entities/task.dart';
import 'base_repository.dart';

/// Repository interface for task operations
abstract class TaskRepository extends BaseRepository<Task> {
  /// Stream of domain events emitted by this repository
  @override
  Stream<DomainEvent> get events;
  
  /// Creates a new task
  @override
  Stream<Task> create(Task task);

  /// Updates an existing task
  @override
  Stream<Task> update(Task task);

  /// Deletes a task by ID
  @override
  Stream<void> delete(String id);

  /// Lists tasks with optional filters
  @override
  Stream<List<Task>> list({Map<String, dynamic>? filters});

  /// Reads a task by ID
  @override
  Stream<Task> read(String id);

  /// Get tasks by status
  Future<List<Task>> getByStatus(TaskStatus status);
  
  /// Get tasks by priority
  Future<List<Task>> getByPriority(TaskPriority priority);
  
  /// Get subtasks for a given task
  Future<List<Task>> getSubtasks(String taskId);
  
  /// Update task status
  Future<Task> updateStatus(String taskId, TaskStatus status);
  
  /// Initializes the repository
  Future<void> initialize();

  /// Disposes of any resources
  @override
  void dispose();
} 