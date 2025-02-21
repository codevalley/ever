import '../base.dart';

/// Command for listing all tasks
class ListTasksCommand extends EverCommand {
  @override
  final name = 'list';
  
  @override
  final description = 'List all tasks';

  ListTasksCommand({
    required super.presenter,
    super.logger,
  });

  @override
  Future<int> execute() async {
    await presenter.listTasks();
    return ExitCode.success.code;
  }
} 