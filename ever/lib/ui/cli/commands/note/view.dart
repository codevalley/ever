import 'dart:async';

import '../../formatters/note.dart';
import '../base.dart';

/// Command for viewing a single note by ID
class ViewNoteCommand extends EverCommand {
  @override
  final name = 'view';
  
  @override
  final description = 'View a single note by ID';

  ViewNoteCommand({
    required super.presenter,
    super.logger,
  }) {
    argParser.addOption(
      'id',
      abbr: 'i',
      help: 'ID of the note to view',
      mandatory: true,
    );
  }

  @override
  Future<int> execute() async {
    final id = argResults?['id'] as String?;
    
    if (id == null) {
      logger.err('Note ID is required');
      return ExitCode.usage.code;
    }

    try {
      final note = await presenter.getNote(id);

      final formatter = NoteFormatter();
      logger.info(formatter.formatNote(note));
      return ExitCode.success.code;
    } on FormatException {
      logger.err('Invalid note ID format');
      return ExitCode.usage.code;
    }
  }
}
