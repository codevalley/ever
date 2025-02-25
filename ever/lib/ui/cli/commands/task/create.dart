import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../../../domain/entities/task.dart';
import '../base.dart';

/// Command for creating a new task
class CreateTaskCommand extends EverCommand {
  @override
  final name = 'create';
  
  @override
  final description = 'Create a new task';

  CreateTaskCommand({
    required super.presenter,
    super.logger,
  }) {
    argParser
      ..addOption(
        'content',
        abbr: 'c',
        help: 'Content of the task',
      )
      ..addOption(
        'status',
        abbr: 's',
        help: 'Status of the task (todo, in_progress, done)',
        defaultsTo: 'todo',
      )
      ..addOption(
        'priority',
        abbr: 'p',
        help: 'Priority of the task (low, medium, high)',
        defaultsTo: 'medium',
      )
      ..addOption(
        'due',
        abbr: 'd',
        help: 'Due date of the task (YYYY-MM-DD)',
      )
      ..addMultiOption(
        'tags',
        abbr: 't',
        help: 'Tags for the task',
        splitCommas: true,
      )
      ..addOption(
        'parent',
        help: 'Parent task ID',
      )
      ..addOption(
        'topic',
        help: 'Topic ID',
      )
      ..addFlag(
        'interactive',
        abbr: 'i',
        help: 'Create task in interactive mode',
        defaultsTo: false,
      );
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
          'Invalid status: $status. Must be one of: todo, in_progress, done',
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
          'Invalid priority: $priority. Must be one of: low, medium, high',
          usage,
        );
    }
  }

  DateTime? _parseDate(String? date) {
    if (date == null) return null;
    try {
      return DateTime.parse(date);
    } catch (e) {
      throw UsageException(
        'Invalid date format: $date. Must be YYYY-MM-DD',
        usage,
      );
    }
  }

  @override
  Future<int> execute() async {
    String? content;
    String status = argResults?['status'] as String;
    String priority = argResults?['priority'] as String;
    String? dueDate = argResults?['due'] as String?;
    List<String> tags = argResults?['tags'] as List<String>? ?? [];
    String? parentId = argResults?['parent'] as String?;
    String? topicId = argResults?['topic'] as String?;
    
    final isInteractive = argResults?['interactive'] as bool? ?? false;
    
    if (isInteractive) {
      stdout.write('Enter task content: ');
      content = stdin.readLineSync();
      
      stdout.write('Enter task status (todo, in_progress, done) [todo]: ');
      final inputStatus = stdin.readLineSync();
      if (inputStatus?.isNotEmpty ?? false) status = inputStatus!;
      
      stdout.write('Enter task priority (low, medium, high) [medium]: ');
      final inputPriority = stdin.readLineSync();
      if (inputPriority?.isNotEmpty ?? false) priority = inputPriority!;
      
      stdout.write('Enter due date (YYYY-MM-DD) [optional]: ');
      final inputDueDate = stdin.readLineSync();
      if (inputDueDate?.isNotEmpty ?? false) dueDate = inputDueDate;
      
      stdout.write('Enter tags (comma separated) [optional]: ');
      final inputTags = stdin.readLineSync();
      if (inputTags?.isNotEmpty ?? false) {
        tags = inputTags!.split(',').map((t) => t.trim()).toList();
      }
      
      stdout.write('Enter parent task ID [optional]: ');
      final inputParentId = stdin.readLineSync();
      if (inputParentId?.isNotEmpty ?? false) parentId = inputParentId;
      
      stdout.write('Enter topic ID [optional]: ');
      final inputTopicId = stdin.readLineSync();
      if (inputTopicId?.isNotEmpty ?? false) topicId = inputTopicId;
    } else {
      content = argResults?['content'] as String?;
      
      if (content == null) {
        throw UsageException(
          'Content is required.',
          usage,
        );
      }
    }

    await presenter.createTask(
      content: content!,
      status: _parseStatus(status),
      priority: _parsePriority(priority),
      dueDate: _parseDate(dueDate),
      tags: tags.isEmpty ? null : tags,
      parentId: parentId,
      topicId: topicId,
    );
    
    return ExitCode.success.code;
  }
} 