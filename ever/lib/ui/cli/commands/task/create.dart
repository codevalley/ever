import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

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
        'title',
        abbr: 't',
        help: 'Title of the task',
      )
      ..addOption(
        'description',
        abbr: 'd',
        help: 'Description of the task',
      )
      ..addFlag(
        'interactive',
        abbr: 'i',
        help: 'Create task in interactive mode',
        defaultsTo: false,
      );
  }

  @override
  Future<int> execute() async {
    String? title;
    String? description;
    
    final isInteractive = argResults?['interactive'] as bool? ?? false;
    
    if (isInteractive) {
      stdout.write('Enter task title: ');
      title = stdin.readLineSync();
      
      stdout.write('Enter task description (press Enter to skip): ');
      description = stdin.readLineSync();
      if (description?.isEmpty ?? true) description = null;
    } else {
      title = argResults?['title'] as String?;
      description = argResults?['description'] as String?;
      
      if (title == null) {
        throw UsageException(
          'Title is required.',
          usage,
        );
      }
    }

    await presenter.createTask(title: title!, description: description);
    return ExitCode.success.code;
  }
} 