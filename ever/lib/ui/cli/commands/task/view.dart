import 'package:args/command_runner.dart';

import '../base.dart';

/// Command for viewing a specific task
class ViewTaskCommand extends EverCommand {
  @override
  final name = 'view';
  
  @override
  final description = 'View a specific task';

  ViewTaskCommand({
    required super.presenter,
    super.logger,
  }) {
    argParser.addOption(
      'id',
      abbr: 'i',
      help: 'ID of the task to view',
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

    await presenter.viewTask(id);
    return ExitCode.success.code;
  }
} 