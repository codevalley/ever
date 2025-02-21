import '../base.dart';
import 'create.dart';
import 'delete.dart';
import 'list.dart';
import 'update.dart';
import 'view.dart';

/// Group command for task-related operations
class TaskCommand extends EverCommand {
  @override
  final name = 'task';
  
  @override
  final description = 'Task management commands';

  TaskCommand({
    required super.presenter,
    super.logger,
  }) {
    addSubcommand(CreateTaskCommand(presenter: presenter));
    addSubcommand(UpdateTaskCommand(presenter: presenter));
    addSubcommand(DeleteTaskCommand(presenter: presenter));
    addSubcommand(ListTasksCommand(presenter: presenter));
    addSubcommand(ViewTaskCommand(presenter: presenter));
  }

  @override
  Future<int> execute() async {
    // Print usage if no subcommand is provided
    printUsage();
    return ExitCode.success.code;
  }
} 