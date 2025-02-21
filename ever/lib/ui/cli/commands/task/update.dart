import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

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
        'title',
        abbr: 't',
        help: 'New title of the task',
      )
      ..addOption(
        'description',
        abbr: 'd',
        help: 'New description of the task',
      )
      ..addOption(
        'status',
        abbr: 's',
        help: 'New status of the task (todo, in_progress, done)',
        allowed: ['todo', 'in_progress', 'done'],
      )
      ..addFlag(
        'interactive',
        help: 'Update task in interactive mode',
        defaultsTo: false,
      );
  }

  @override
  Future<int> execute() async {
    final id = argResults?['id'] as String;
    String? title;
    String? description;
    String? status;
    
    final isInteractive = argResults?['interactive'] as bool? ?? false;
    
    if (isInteractive) {
      stdout.write('Enter new title (press Enter to skip): ');
      title = stdin.readLineSync();
      if (title?.isEmpty ?? true) title = null;
      
      stdout.write('Enter new description (press Enter to skip): ');
      description = stdin.readLineSync();
      if (description?.isEmpty ?? true) description = null;
      
      stdout.write('Enter new status (todo/in_progress/done, press Enter to skip): ');
      status = stdin.readLineSync();
      if (status?.isEmpty ?? true) status = null;
      
      if (status != null && !['todo', 'in_progress', 'done'].contains(status)) {
        throw UsageException(
          'Invalid status. Must be one of: todo, in_progress, done',
          usage,
        );
      }
    } else {
      title = argResults?['title'] as String?;
      description = argResults?['description'] as String?;
      status = argResults?['status'] as String?;
    }

    if (title == null && description == null && status == null) {
      throw UsageException(
        'At least one of title, description, or status must be provided.',
        usage,
      );
    }

    await presenter.updateTask(
      id,
      title: title,
      description: description,
      status: status,
    );
    return ExitCode.success.code;
  }
} 