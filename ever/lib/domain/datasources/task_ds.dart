import '../entities/task.dart';
import 'base_ds.dart';

/// Data source interface for Task operations
abstract class TaskDataSource extends BaseDataSource<Task> {
  /// Get tasks by status
  Future<List<Task>> getByStatus(TaskStatus status);
  
  /// Get tasks by priority
  Future<List<Task>> getByPriority(TaskPriority priority);
  
  /// Get subtasks for a given task
  Future<List<Task>> getSubtasks(String taskId);
  
  /// Update task status
  Future<Task> updateStatus(String taskId, TaskStatus status);
}
