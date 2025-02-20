import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../base.dart';

/// Command for updating an existing note
class UpdateNoteCommand extends EverCommand {
  @override
  final name = 'update';
  
  @override
  final description = 'Update an existing note';

  UpdateNoteCommand({
    required super.presenter,
    super.logger,
  }) {
    argParser
      ..addOption(
        'id',
        abbr: 'i',
        help: 'ID of the note to update',
        mandatory: true,
      )

      ..addOption(
        'content',
        abbr: 'c',
        help: 'New content for the note',
      )
      ..addFlag(
        'interactive',
        help: 'Update note in interactive mode',
        defaultsTo: false,
      );
  }

  @override
  Future<int> execute() async {
    final id = argResults?['id'] as String;
    String? content;
    
    final isInteractive = argResults?['interactive'] as bool? ?? false;
    
    if (isInteractive) {
      final note = await presenter.getNote(id);
      
      stdout.write('Current content:\n${note.content}\n');
      stdout.write('New content (press Ctrl+D when done, empty line to keep current):\n');
      final contentInput = await _readMultilineInput();
      content = contentInput.isNotEmpty ? contentInput : null;
    } else {
      content = argResults?['content'] as String?;
      
      if (content == null) {
        throw UsageException(
          'Content must be provided.',
          usage,
        );
      }
    }

    await presenter.updateNote(id, content: content);
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