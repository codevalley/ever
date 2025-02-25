import 'dart:async';

import '../../formatters/task.dart';
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
    // Create a completer to wait for tasks
    final completer = Completer<void>();
    StreamSubscription? subscription;

    // Subscribe to state changes
    subscription = presenter.state.listen((state) {
      if (!state.isLoading && state.error == null) {
        final formatter = TaskFormatter();
        logger.info(formatter.formatTaskList(state.tasks));
        if (!completer.isCompleted) completer.complete();
      } else if (state.error != null) {
        if (!completer.isCompleted) {
          completer.completeError(state.error!);
        }
      }
    });

    try {
      // List tasks
      await presenter.listTasks();
      // Wait for completion with timeout
      await completer.future.timeout(Duration(seconds: 10));
      return ExitCode.success.code;
    } catch (e) {
      logger.err(e.toString());
      return ExitCode.software.code;
    } finally {
      await subscription.cancel();
    }
  }
} 