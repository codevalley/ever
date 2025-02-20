import 'dart:async';


import '../../formatters/note.dart';
import '../base.dart';

/// Command for listing notes
class ListNotesCommand extends EverCommand {
  @override
  final name = 'list';
  
  @override
  final description = 'List all notes';

  ListNotesCommand({
    required super.presenter,
    super.logger,
  }) {
    argParser.addFlag(
      'all',
      abbr: 'a',
      help: 'Show all notes including archived ones',
      defaultsTo: false,
    );
  }

  @override
  Future<int> execute() async {
    final includeArchived = argResults?['all'] as bool? ?? false;
    
    final notes = await presenter.listNotes(includeArchived: includeArchived);
    final formatter = NoteFormatter();
    
    logger.info(formatter.formatNoteList(notes));
    return ExitCode.success.code;
  }
} 