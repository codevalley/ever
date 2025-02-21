import 'dart:async';
import 'dart:io';


import '../../formatters/note.dart';
import '../base.dart';

/// Command for deleting a note
class DeleteNoteCommand extends EverCommand {
  @override
  final name = 'delete';
  
  @override
  final description = 'Delete a note';

  DeleteNoteCommand({
    required super.presenter,
    super.logger,
  }) {
    argParser
      ..addOption(
        'id',
        abbr: 'i',
        help: 'ID of the note to delete',
        mandatory: true,
      )
      ..addFlag(
        'force',
        abbr: 'f',
        help: 'Force delete without confirmation',
        defaultsTo: false,
      );
  }

  @override
  Future<int> execute() async {
    final id = argResults?['id'] as String;
    final force = argResults?['force'] as bool? ?? false;
    
    if (!force) {
      final note = await presenter.getNote(id).first;
      logger.info('About to delete note:');
      logger.info(NoteFormatter().formatNote(note));
      
      final confirmed = await _confirmDeletion();
      if (!confirmed) {
        logger.info('Deletion cancelled.');
        return ExitCode.success.code;
      }
    }

    await presenter.deleteNote(id);
    logger.success('Note deleted successfully.');
    return ExitCode.success.code;
  }

  Future<bool> _confirmDeletion() async {
    stdout.write('Are you sure you want to delete this note? [y/N]: ');
    final input = stdin.readLineSync()?.toLowerCase();
    return input == 'y' || input == 'yes';
  }
} 