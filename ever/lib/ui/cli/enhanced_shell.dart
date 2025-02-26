// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' as mason_logger hide ExitCode;

import '../../implementations/config/api_config.dart';
import 'commands/base.dart';

/// Enhanced shell command with a nice welcome screen
class EnhancedShellCommand extends EverCommand {
  @override
  final name = 'shell';
  
  @override
  final description = 'Start interactive shell with enhanced features';

  final CommandRunner<int> _runner;
  bool _isProcessing = false;
  bool _isCleanedUp = false;
  mason_logger.Progress? _progress;
  late StreamSubscription<dynamic> _stateSubscription;
  
  EnhancedShellCommand({
    required super.presenter,
    required CommandRunner<int> runner,
    super.logger,
  }) : _runner = runner;

  @override
  Future<void> execute() async {
    try {
      // Display welcome message
      _displayWelcomeMessage();
      
      // Display login status if authenticated
      await _displayLoginStatus();
      
      // Subscribe to state changes
      _stateSubscription = presenter.state.listen((state) {
        if (state.isLoading && !_isProcessing) {
          _isProcessing = true;
          _progress = logger.progress('Processing');
        } else if (!state.isLoading && _isProcessing) {
          _isProcessing = false;
          _progress?.complete();
          _progress = null;
        }
      });

      try {
        while (true) {
          // Display prompt
          stdout.write('ever> ');
          
          // Read line using stdin
          final input = stdin.readLineSync();
          
          if (input == null || input.trim().isEmpty) {
            continue;
          }

          // Handle exit command
          if (input.trim().toLowerCase() == 'exit' || input.trim().toLowerCase() == 'quit') {
            await _cleanupAndExit();
            break;
          }

          try {
            // Parse and run command
            final result = await _runner.run(input.split(' '));
            if (result != null && result != ExitCode.success.code) {
              logger.err('Command failed with exit code: $result');
            }
          } catch (e) {
            logger.err(e.toString());
          }
        }
      } finally {
        // Only call cleanup if it hasn't been called already by the exit command
        if (!_isCleanedUp) {
          await _cleanupAndExit();
        }
      }
    } catch (e) {
      logger.err('Error in shell: $e');
      rethrow;
    }
  }

  /// Clean up resources and prepare for exit
  Future<void> _cleanupAndExit() async {
    // Prevent double cleanup
    if (_isCleanedUp) return;
    
    _isCleanedUp = true;
    logger.info('Goodbye!');
    
    // Complete any in-progress operations
    if (_isProcessing) {
      _isProcessing = false;
      _progress?.complete();
      _progress = null;
    }
    
    // Force complete any other progress indicators that might be active
    logger.progress('').complete();
    
    // Cancel state subscription
    await _stateSubscription.cancel();
    
    // Dispose presenter resources
    await presenter.dispose();
    
    // Force exit to terminate any hanging processes
    // Add a small delay to allow cleanup to complete
    Timer(Duration(milliseconds: 100), () {
      exit(0);
    });
  }

  /// Displays login status if user is authenticated
  Future<void> _displayLoginStatus() async {
    try {
      final currentState = await presenter.state.first;
      if (currentState.isAuthenticated && currentState.currentUser != null) {
        final username = currentState.currentUser!.username;
        print('$_green✓ Logged in as $username$_reset');
        print('');
      }
    } catch (e) {
      // Ignore errors when checking state
    }
  }

  /// Displays a welcome message with ASCII art and helpful information
  void _displayWelcomeMessage() {
    // Display ASCII art
    // courtesy of https://patorjk.com/software/taag/#p=display&f=Big&t=EVER
    print('''
$_yellow
  ╔═╗╦  ╦     ╔═╗╦  ╦╔═╗╦═╗
  ║  ║  ║───  ║╣ ╚╗╔╝║╣ ╠╦╝
  ╚═╝╩═╝╩     ╚═╝ ╚╝ ╚═╝╩╚═
                                                
$_reset''');
    
    // Display API URL in a box
    print('API URL: ${ApiConfig.apiBaseUrl}');
    print('');
    
    // Display available commands in a box
    _printBox('Available Commands', _yellow);
    
    // List commands with descriptions
    final commands = _runner.commands.keys.toList()..sort();
    for (final command in commands) {
      final description = _runner.commands[command]?.description ?? '';
      print(' - $_green$command$_reset: $description');
    }
    
    print('');
    
    // Display tips in a box
    _printBox('Tips', _green);
    
    print(' - Type "help" to see available commands');
    print(' - Type "exit" or "quit" to exit');
    print('');
  }
  
  /// Print a simple box with a title
  void _printBox(String title, String color) {
    final width = 60;
    final padding = ' ' * ((width - title.length) ~/ 2);
    final extraSpace = (width - title.length) % 2 != 0 ? ' ' : '';
    
    print('$color+${'-' * width}+');
    print('|$padding$title$padding$extraSpace|');
    print('+${'-' * width}+$_reset');
    print('');
  }
  
  // ANSI color codes
  static const _reset = '\x1B[0m';
  static const _green = '\x1B[32m';
  static const _yellow = '\x1B[33m';
  //static const _cyan = '\x1B[36m';
} 