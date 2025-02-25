import 'dart:async';
import 'package:args/command_runner.dart';

import '../../../../domain/events/task_events.dart';
import '../../formatters/task.dart';
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

    // Create a completer to wait for task
    final completer = Completer<void>();
    StreamSubscription? subscription;

    // Subscribe to state changes for errors
    subscription = presenter.state.listen((state) {
      if (state.error != null) {
        if (!completer.isCompleted) {
          completer.completeError(state.error!);
        }
      }
    });

    // Subscribe to task events
    StreamSubscription? taskSubscription;
    taskSubscription = presenter.events.listen((event) {
      if (event is TaskRetrieved) {
        final formatter = TaskFormatter();
        logger.info(formatter.formatTask(event.task));
        if (!completer.isCompleted) completer.complete();
      }
    });

    try {
      // View task
      await presenter.viewTask(id);
      // Wait for completion with timeout
      await completer.future.timeout(Duration(seconds: 10));
      return ExitCode.success.code;
    } catch (e) {
      logger.err(e.toString());
      return ExitCode.software.code;
    } finally {
      await subscription.cancel();
      await taskSubscription.cancel();
    }
  }
} 