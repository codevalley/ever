import 'package:mason_logger/mason_logger.dart' hide ExitCode;

import '../../domain/presenter/ever_presenter.dart';
import 'commands/base.dart';
import 'commands/note/note.dart';
import 'commands/task/task.dart';
import 'commands/user/login.dart';
import 'commands/user/logout.dart';
import 'commands/user/profile.dart';
import 'commands/user/register.dart';
import 'enhanced_shell.dart';

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
      ..addCommand(TaskCommand(presenter: presenter, logger: this.logger))
      ..addCommand(EnhancedShellCommand(
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
      
      // Check for cached credentials if no specific command is provided
      if (args.isEmpty || (args.length == 2 && args[0] == '--api-url')) {
        final cachedSecret = await presenter.getCachedUserSecret();
        
        if (cachedSecret != null) {
          // Ask user if they want to auto-login
          final autoLogin = logger.confirm(
            '👋 Welcome back! Would you like to auto-login with your cached credentials?',
            defaultValue: true,
          );
          
          if (autoLogin) {
            try {
              // Instead of trying to login directly with the cached secret,
              // run the login command which will handle the cached secret properly
              logger.info('🔄 Auto-logging in...');
              final loginArgs = ['login'];
              
              // Add API URL if provided
              if (args.length == 2 && args[0] == '--api-url') {
                loginArgs.addAll(args);
              }
              
              // Run the login command
              await _registry.run(loginArgs);
              logger.success('🔐 Auto-login successful!');
            } catch (e) {
              logger.err('❌ Auto-login failed: ${e.toString()}');
              logger.info('Please login manually.');
            }
          }
        }
        
        // Start shell mode regardless of login outcome
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