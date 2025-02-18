import 'dart:async';
import 'dart:io';
import '../../formatters/user.dart';
import '../base.dart';


/// Command for user login
class LoginCommand extends EverCommand {
  @override
  final name = 'login';
  
  @override
  final description = 'Login to your account';

  LoginCommand({
    required super.presenter,
    super.logger,
  }) {
    argParser.addOption(
      'secret',
      abbr: 's',
      help: 'User secret obtained during registration',
    );
  }

  @override
  Future<void> execute() async {
    String? userSecret;
    
    // Try to get cached secret first
    try {
      userSecret = await presenter.getCachedUserSecret();
    } catch (e) {
      // Ignore error, will prompt for secret
    }

    if (userSecret == null) {
      // Get the secret from command line argument if provided
      userSecret = argResults?['secret'] as String?;
      
      // If not provided as argument, prompt for it
      if (userSecret == null) {
        stdout.write('Enter your secret: ');
        // Temporarily disable echo
        stdin.echoMode = false;
        userSecret = stdin.readLineSync();
        // Re-enable echo and print newline
        stdin.echoMode = true;
        stdout.write('\n');
      }
      
      if (userSecret == null || userSecret.trim().isEmpty) {
        logger.err('Secret cannot be empty');
        return;
      }
    } else {
      logger.info('Using cached secret');
    }

    final completer = Completer<void>();
    StreamSubscription? subscription;

    try {
      subscription = presenter.state.listen(
        (state) {
          if (!state.isLoading) {
            if (state.error != null) {
              if (!completer.isCompleted) {
                logger.err(state.error!);
                completer.complete(); // Complete normally, error already logged
              }
            } else if (state.currentUser != null) {
              if (!completer.isCompleted) {
                logger.info(UserFormatter().format(state.currentUser!));
                logger.success('Login successful!');
                completer.complete();
              }
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            logger.err(error.toString());
            completer.complete(); // Complete normally, error already logged
          }
        },
      );

      // Start login process
      await presenter.login(userSecret.trim());

      // Wait for completion with timeout
      await completer.future.timeout(
        Duration(seconds: 30),
        onTimeout: () {
          logger.err('Login timed out after 30 seconds');
          return;
        },
      );
    } catch (e) {
      logger.err(e.toString());
    } finally {
      await subscription?.cancel();
    }
  }
} 