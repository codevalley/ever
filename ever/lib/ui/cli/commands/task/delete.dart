import 'package:args/command_runner.dart';

import '../base.dart';

/// Command for deleting a task
class DeleteTaskCommand extends EverCommand {
  @override
  final name = 'delete';
  
  @override
  final description = 'Delete a task';

  DeleteTaskCommand({
    required super.presenter,
    super.logger,
  }) {
    argParser.addOption(
      'id',
      abbr: 'i',
      help: 'ID of the task to delete',
      mandatory: true,
    );
  }

  @override
  Future<int> execute() async {
    final id = argResults?['id'] as String;
    
    if (id.isEmpty) {
      throw UsageException(
        'Task ID is required.',
        usage,
      );
    }

    await presenter.deleteTask(id);
    return ExitCode.success.code;
  }
} 