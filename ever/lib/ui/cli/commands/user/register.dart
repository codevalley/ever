
import 'package:args/command_runner.dart' show UsageException;
import '../../formatters/user.dart';
import '../base.dart';

/// Command for user registration
class RegisterCommand extends EverCommand {
  @override
  final name = 'register';
  
  @override
  final description = 'Register a new user';

  RegisterCommand({
    required super.presenter,
    super.logger,
  }) {
    argParser.addOption(
      'username',
      abbr: 'u',
      help: 'Username for registration',
    );
  }

  @override
  Future<void> execute() async {
    String? username = argResults?['username'];
    
    // If username not provided via args, prompt for it
    if (username == null || username.isEmpty) {
      username = logger.prompt(
        'Enter username:',
        defaultValue: null,
      );
    }

    if (username.isEmpty) {
      throw UsageException('Username is required', usage);
    }

    // Register user
    await presenter.register(username);

    // Wait for state to update
    await for (final state in presenter.state) {
      if (!state.isLoading) {
        if (state.currentUser != null) {
          logger.info(UserFormatter().format(state.currentUser!));
          logger.success('Registration successful! Save your secret for login.');
          break;
        } else if (state.error != null) {
          // Error already handled by base command
          break;
        }
      }
    }
  }
} 