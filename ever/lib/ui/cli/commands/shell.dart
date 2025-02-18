import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart' as mason;

import '../../../domain/presenter/ever_presenter.dart';
import 'base.dart';

/// Command for interactive shell mode
class ShellCommand extends EverCommand {
  @override
  final name = 'shell';
  
  @override
  final description = 'Start interactive shell';

  final CommandRunner _runner;
  bool _isProcessing = false;
  StreamSubscription<EverState>? _shellStateSubscription;
  mason.Progress? _progress;

  ShellCommand({
    required super.presenter,
    required CommandRunner runner,
    super.logger,
  }) : _runner = runner;

  @override
  Future<void> execute() async {
    // Subscribe to state changes
    _shellStateSubscription = presenter.state.listen((state) {
      _isProcessing = state.isLoading;
      if (_isProcessing) {
        _progress = logger.progress('Processing');
      } else if (_progress != null) {
        _progress?.complete();
        _progress = null;
      }
    });

    while (true) {
      // Get command from user
      final input = logger.prompt('ever>', defaultValue: '');
      
      if (input.trim().isEmpty) {
        continue;
      }

      // Handle exit command
      if (input.trim().toLowerCase() == 'exit' || input.trim().toLowerCase() == 'quit') {
        await _cleanup();
        logger.info('Goodbye!');
        exit(0);
      }

      try {
        // Parse and run command
        final result = await _runner.run(input.split(' '));
        if (result != null && result != mason.ExitCode.success.code) {
          logger.err('Command failed with exit code: $result');
        }
      } catch (e) {
        logger.err(e.toString());
      }
    }
  }

  Future<void> _cleanup() async {
    // Cancel state subscription
    await _shellStateSubscription?.cancel();
    _shellStateSubscription = null;

    // Complete any in-progress operation
    if (_isProcessing && _progress != null) {
      _progress?.complete();
      _progress = null;
      _isProcessing = false;
    }
  }
} 