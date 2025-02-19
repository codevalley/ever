import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

import '../../../core/logging.dart';
import '../../../domain/presenter/ever_presenter.dart';
import '../../../implementations/config/api_config.dart';
import '../formatters/error.dart';
import '../formatters/success.dart';

/// Base class for all CLI commands
abstract class EverCommand extends Command<int> {
  /// The presenter instance for state management
  final EverPresenter presenter;
  
  /// Logger for CLI output
  final Logger logger;
  
  /// State subscription for handling presenter state changes
  StreamSubscription<EverState>? _stateSubscription;

  EverCommand({
    required this.presenter,
    Logger? logger,
  }) : logger = logger ?? Logger();

  /// Set up state handling
  void _setupStateHandling() {
    _stateSubscription?.cancel();
    _stateSubscription = presenter.state.listen(_handleState);
  }

  /// Handle state changes from the presenter
  void _handleState(EverState state) {
    if (state.isLoading) {
      logger.progress('Processing...');
    } else {
      logger.progress('').complete();
      if (state.error != null) {
        logger.err(ErrorFormatter().format(state.error!));
      } else if (state.currentUser != null) {
        logger.success(SuccessFormatter().format('Operation completed successfully'));
      }
    }
  }

  @override
  Future<int> run() async {
    try {
      _setupStateHandling();
      await execute();
      return ExitCode.success.code;
    } catch (e) {
      logger.err(ErrorFormatter().format(e.toString()));
      // Don't rethrow, just return error code
      return ExitCode.software.code;
    } finally {
      await _cleanup();
    }
  }

  /// Execute the command logic
  Future<void> execute();

  /// Clean up resources
  Future<void> _cleanup() async {
    await _stateSubscription?.cancel();
  }
}

/// Command to exit the CLI
class ExitCommand extends Command<int> {
  @override
  final name = 'exit';
  
  @override
  final description = 'Exit the CLI';

  final Logger logger;

  ExitCommand({Logger? logger}) : logger = logger ?? Logger();

  @override
  Future<int> run() async {
    logger.info('Goodbye!');
    exit(0);
  }
}

/// Registry for all available commands
class CommandRegistry {
  final EverPresenter presenter;
  final Logger logger;
  late final CommandRunner<int> _runner;

  /// Get the command runner instance
  CommandRunner<int> get runner => _runner;

  CommandRegistry({
    required this.presenter,
    Logger? logger,
  }) : logger = logger ?? Logger() {
    _runner = CommandRunner<int>(
      'ever',
      'Ever CLI - A command line interface for Ever app',
    );

    // Add global options
    _runner.argParser
      ..addOption(
        'api-url',
        help: 'Override the API base URL',
        valueHelp: 'https://api.example.com',
      )
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Enable verbose (debug) logging',
        negatable: false,
      );

    // Add exit command
    _runner.addCommand(ExitCommand(logger: logger));
  }

  /// Add a command to the registry
  void addCommand(Command<int> command) {
    _runner.addCommand(command);
  }

  /// Run a command with arguments
  Future<int> run(List<String> args) async {
    try {
      logger.info('Processing args: $args');
      
      // Parse global options first
      final results = _runner.argParser.parse(args);
      logger.info('Parsed options: ${results.options}');
      
      // Update API URL if provided
      final apiUrl = results['api-url'] as String?;
      if (apiUrl != null) {
        ApiConfig.updateBaseUrl(apiUrl);
        logger.info('Using API URL: ${ApiConfig.apiBaseUrl}');
      }

      // Handle verbose flag
      final verbose = results['verbose'] as bool;
      logger.info('Verbose flag: $verbose');
      
      if (verbose) {
        logger.info('Enabling verbose logging...');
        initLogging(LogConfig(
          enabled: true,
          minLevel: LogLevel.debug,
          showTimestamp: true,
          showLevel: true,
        ));
        logger.detail('Verbose logging enabled');
      }

      // Extract command and command arguments
      final commandArgs = args.where((arg) => !arg.startsWith('-')).toList();
      final command = commandArgs.isEmpty ? 'shell' : commandArgs[0];
      final remainingArgs = commandArgs.isEmpty ? [] : commandArgs.sublist(1);

      logger.info('Running command: $command with args: $remainingArgs');

      try {
        final result = await _runner.runCommand(
          await _runner.argParser.parse([command, ...remainingArgs])
        );
        return result ?? ExitCode.success.code;
      } on UsageException catch (e) {
        logger.err(e.message);
        logger.info(e.usage);
        return ExitCode.usage.code;
      }
    } catch (e) {
      logger.err(ErrorFormatter().format(e.toString()));
      return ExitCode.software.code;
    }
  }
}

/// Exit codes for the CLI
class ExitCode {
  static const success = ExitCode._(0);
  static const software = ExitCode._(1);
  static const usage = ExitCode._(64);
  static const unavailable = ExitCode._(69);
  static const ioError = ExitCode._(74);

  final int code;
  const ExitCode._(this.code);
} 