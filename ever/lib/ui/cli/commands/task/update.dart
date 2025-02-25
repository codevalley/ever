import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../../../domain/entities/task.dart';
import '../../../../domain/events/task_events.dart';
import '../base.dart';

/// Command for updating an existing task
class UpdateTaskCommand extends EverCommand {
  @override
  final name = 'update';
  
  @override
  final description = 'Update an existing task';

  UpdateTaskCommand({
    required super.presenter,
    super.logger,
  }) {
    argParser
      ..addOption(
        'id',
        abbr: 'i',
        help: 'ID of the task to update',
        mandatory: true,
      )
      ..addOption(
        'content',
        abbr: 'c',
        help: 'New content for the task',
      )
      ..addOption(
        'status',
        abbr: 's',
        help: 'New status of the task (todo, in_progress, done)',
        allowed: ['todo', 'in_progress', 'done'],
      )
      ..addOption(
        'priority',
        abbr: 'p',
        help: 'New priority of the task (low, medium, high)',
        allowed: ['low', 'medium', 'high'],
      )
      ..addOption(
        'due-date',
        abbr: 'd',
        help: 'New due date for the task (YYYY-MM-DD)',
      )
      ..addMultiOption(
        'tags',
        abbr: 't',
        help: 'New tags for the task',
        splitCommas: true,
      )
      ..addOption(
        'parent-id',
        help: 'New parent task ID',
      )
      ..addOption(
        'topic-id',
        help: 'New topic ID',
      )
      ..addFlag(
        'interactive',
        help: 'Update task in interactive mode',
        defaultsTo: false,
      );
  }

  String _formatStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return 'todo';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.done:
        return 'done';
    }
  }

  String _formatPriority(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'low';
      case TaskPriority.medium:
        return 'medium';
      case TaskPriority.high:
        return 'high';
    }
  }

  @override
  Future<int> execute() async {
    final id = argResults?['id'] as String;
    String? content;
    TaskStatus? status;
    TaskPriority? priority;
    DateTime? dueDate;
    List<String>? tags;
    String? parentId;
    String? topicId;
    
    final isInteractive = argResults?['interactive'] as bool? ?? false;

    // Get current task first
    final completer = Completer<void>();
    StreamSubscription? subscription;
    Task? currentTask;

    // Subscribe to task events
    subscription = presenter.events.listen((event) {
      if (event is TaskRetrieved) {
        currentTask = event.task;
        if (!completer.isCompleted) completer.complete();
      }
    });

    try {
      // Get current task
      await presenter.viewTask(id);
      await completer.future.timeout(Duration(seconds: 10));
    } catch (e) {
      logger.err('Failed to get current task: $e');
      await subscription.cancel();
      return ExitCode.software.code;
    } finally {
      await subscription.cancel();
    }

    if (currentTask == null) {
      logger.err('Task not found');
      return ExitCode.software.code;
    }
    
    if (isInteractive) {
      stdout.write('Enter new content (current: ${currentTask!.content}): ');
      content = stdin.readLineSync();
      if (content?.isEmpty ?? true) content = null;
      
      stdout.write('Enter new status (todo/in_progress/done) (current: ${_formatStatus(currentTask!.status)}): ');
      final statusStr = stdin.readLineSync();
      if (statusStr?.isNotEmpty ?? false) {
        status = _parseStatus(statusStr!);
      }
      
      stdout.write('Enter new priority (low/medium/high) (current: ${_formatPriority(currentTask!.priority)}): ');
      final priorityStr = stdin.readLineSync();
      if (priorityStr?.isNotEmpty ?? false) {
        priority = _parsePriority(priorityStr!);
      }
      
      stdout.write('Enter new due date (YYYY-MM-DD) (current: ${currentTask!.dueDate?.toLocal().toString().split(' ')[0]}): ');
      final dueDateStr = stdin.readLineSync();
      if (dueDateStr?.isNotEmpty ?? false) {
        dueDate = DateTime.tryParse(dueDateStr!);
        if (dueDate == null) {
          throw UsageException(
            'Invalid date format. Use YYYY-MM-DD',
            usage,
          );
        }
      }
      
      stdout.write('Enter new tags (comma-separated) (current: ${currentTask!.tags.isEmpty ? "none" : currentTask!.tags.join(", ")}): ');
      final tagsStr = stdin.readLineSync();
      if (tagsStr?.isNotEmpty ?? false) {
        tags = tagsStr!.split(',').map((t) => t.trim()).toList();
      }
      
      stdout.write('Enter new parent task ID (current: ${currentTask!.parentId ?? "none"}): ');
      parentId = stdin.readLineSync();
      if (parentId?.isEmpty ?? true) parentId = null;
      
      stdout.write('Enter new topic ID (current: ${currentTask!.topicId ?? "none"}): ');
      topicId = stdin.readLineSync();
      if (topicId?.isEmpty ?? true) topicId = null;
    } else {
      content = argResults?['content'] as String?;
      final statusStr = argResults?['status'] as String?;
      if (statusStr != null) {
        status = _parseStatus(statusStr);
      }
      final priorityStr = argResults?['priority'] as String?;
      if (priorityStr != null) {
        priority = _parsePriority(priorityStr);
      }
      final dueDateStr = argResults?['due-date'] as String?;
      if (dueDateStr != null) {
        dueDate = DateTime.tryParse(dueDateStr);
        if (dueDate == null) {
          throw UsageException(
            'Invalid date format. Use YYYY-MM-DD',
            usage,
          );
        }
      }
      tags = argResults?['tags'] as List<String>?;
      parentId = argResults?['parent-id'] as String?;
      topicId = argResults?['topic-id'] as String?;
    }

    if (content == null && status == null && priority == null && 
        dueDate == null && tags == null && parentId == null && topicId == null) {
      throw UsageException(
        'At least one field must be provided to update.',
        usage,
      );
    }

    await presenter.updateTask(
      id,
      content: content,
      status: status,
      priority: priority,
      dueDate: dueDate,
      tags: tags,
      parentId: parentId,
      topicId: topicId,
    );
    return ExitCode.success.code;
  }

  TaskStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'todo':
        return TaskStatus.todo;
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'done':
        return TaskStatus.done;
      default:
        throw UsageException(
          'Invalid status. Must be one of: todo, in_progress, done',
          usage,
        );
    }
  }

  TaskPriority _parsePriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'medium':
        return TaskPriority.medium;
      case 'high':
        return TaskPriority.high;
      default:
        throw UsageException(
          'Invalid priority. Must be one of: low, medium, high',
          usage,
        );
    }
  }
} 