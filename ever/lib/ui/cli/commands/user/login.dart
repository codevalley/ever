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
      stdout.write('Enter your secret: ');
      // Show visual feedback while typing
      List<String> chars = [];
      while (true) {
        final char = stdin.readByteSync();
        if (char == 10 || char == 13) { // Enter key
          break;
        }
        chars.add('*');
        stdout.write('\r'); // Move cursor to start of line
        stdout.write('Enter your secret: ${chars.join('')}');
      }
      stdout.write('\n'); // New line after input
      
      // Get the actual input without echo
      stdin.echoMode = false;
      userSecret = stdin.readLineSync();
      stdin.echoMode = true;
      
      if (userSecret == null || userSecret.trim().isEmpty) {
        throw Exception('Secret cannot be empty');
      }
    } else {
      logger.info('Using cached secret');
    }

    await presenter.login(userSecret.trim());

    // Wait for state to update with timeout
    var loginCompleted = false;
    var attempts = 0;
    final maxAttempts = 3;
    
    while (!loginCompleted && attempts < maxAttempts) {
      attempts++;
      try {
        await for (final state in presenter.state.timeout(Duration(seconds: 5))) {
          if (!state.isLoading) {
            if (state.currentUser != null) {
              logger.info(UserFormatter().format(state.currentUser!));
              logger.success('Login successful!');
              loginCompleted = true;
              break;
            } else if (state.error != null) {
              // Error already handled by base command
              loginCompleted = true;
              break;
            }
          }
        }
      } catch (e) {
        if (attempts >= maxAttempts) {
          logger.err('Login timed out after multiple attempts');
          throw Exception('Login timed out');
        }
        // Continue to next attempt
      }
    }
  }
} 