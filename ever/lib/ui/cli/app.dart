import 'package:mason_logger/mason_logger.dart' hide ExitCode;

import '../../domain/presenter/ever_presenter.dart';
import 'commands/base.dart';
import 'commands/shell.dart';
import 'commands/note/note.dart';
import 'commands/user/login.dart';
import 'commands/user/logout.dart';
import 'commands/user/profile.dart';
import 'commands/user/register.dart';

/// CLI application entry point
class CliApp {
  final EverPresenter presenter;
  final Logger logger;
  late final CommandRegistry _registry;

  CliApp({
    required this.presenter,
    Logger? logger,
  }) : logger = logger ?? Logger() {
    _registry = CommandRegistry(
      presenter: presenter,
      logger: this.logger,
    );

    // Register commands
    _registry
      ..addCommand(RegisterCommand(presenter: presenter, logger: this.logger))
      ..addCommand(LoginCommand(presenter: presenter, logger: this.logger))
      ..addCommand(LogoutCommand(presenter: presenter, logger: this.logger))
      ..addCommand(ProfileCommand(presenter: presenter, logger: this.logger))
      ..addCommand(NoteCommand(presenter: presenter, logger: this.logger))
      ..addCommand(ShellCommand(
        presenter: presenter,
        runner: _registry.runner,
        logger: this.logger,
      ));
  }

  /// Run the CLI app with arguments
  Future<int> run(List<String> args) async {
    try {
      // Initialize presenter
      await presenter.initialize();
      
      // If no args provided, start shell mode
      if (args.isEmpty) {
        args = ['shell'];
      }
      
      // Run command
      return await _registry.run(args);
    } catch (e) {
      logger.err('Fatal error: $e');
      return ExitCode.software.code;
    }
  }
} 