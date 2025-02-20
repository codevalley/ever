import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../base.dart';

/// Command for creating a new note
class CreateNoteCommand extends EverCommand {
  @override
  final name = 'create';
  
  @override
  final description = 'Create a new note';

  CreateNoteCommand({
    required super.presenter,
    super.logger,
  }) {
    argParser

      ..addOption(
        'content',
        abbr: 'c',
        help: 'Content of the note',
      )
      ..addFlag(
        'interactive',
        abbr: 'i',
        help: 'Create note in interactive mode',
        defaultsTo: false,
      );
  }

  @override
  Future<int> execute() async {
    String? content;
    
    final isInteractive = argResults?['interactive'] as bool? ?? false;
    
    if (isInteractive) {
      stdout.write('Enter note content (press Ctrl+D when done):\n');
      content = await _readMultilineInput();
    } else {
      content = argResults?['content'] as String?;
      
      if (content == null) {
        throw UsageException(
          'Content is required.',
          usage,
        );
      }
    }

    await presenter.createNote(content!);
    return ExitCode.success.code;
  }

  Future<String> _readMultilineInput() async {
    final lines = <String>[];
    String? line;
    
    while ((line = stdin.readLineSync()) != null) {
      lines.add(line!);
    }
    
    return lines.join('\n');
  }
} 