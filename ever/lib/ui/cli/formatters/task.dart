import '../../../domain/entities/task.dart';

/// Formatter for task output
class TaskFormatter {
  /// Format a list of tasks for display
  String formatTaskList(List<Task> tasks) {
    if (tasks.isEmpty) {
      return 'No tasks found.';
    }

    final buffer = StringBuffer();
    buffer.writeln('Tasks:');
    buffer.writeln();

    for (final task in tasks) {
      buffer.writeln(formatTask(task));
    }

    return buffer.toString();
  }

  /// Format a single task for display
  String formatTask(Task task) {
    final status = _formatStatus(task.status);
    final priority = _formatPriority(task.priority);
    final dueDate = task.dueDate != null ? 'Due: ${task.dueDate!.toLocal()}' : '';
    final tags = task.tags.isNotEmpty ? '[${task.tags.join(", ")}]' : '';

    return '${task.id} $status $priority ${task.content} $dueDate $tags';
  }

  String _formatStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return '[ ]';
      case TaskStatus.inProgress:
        return '[~]';
      case TaskStatus.done:
        return '[✓]';
      // ignore: unreachable_switch_default
      default:
        return '[?]';
    }
  }

  String _formatPriority(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return '(!)';
      case TaskPriority.medium:
        return '(!!)';
      case TaskPriority.high:
        return '(!!!)';
      // ignore: unreachable_switch_default
      default:
        return '(?)';
    }
  }
} 