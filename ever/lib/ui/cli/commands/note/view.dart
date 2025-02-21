import 'dart:async';

import '../../../../domain/entities/note.dart';
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
      final completer = Completer<Note>();
      var hasError = false;
      var subscription = presenter.getNote(id).listen(
        (note) {
          if (!completer.isCompleted) {
            completer.complete(note);
          }
        },
        onError: (e) {
          if (!completer.isCompleted && !hasError) {
            hasError = true;
            completer.completeError(e);
          }
        },
        onDone: () {
          if (!completer.isCompleted && !hasError) {
            completer.completeError(Exception('Note not found'));
          }
        },
        cancelOnError: true,
      );

      try {
        final note = await completer.future.timeout(
          Duration(seconds: 10),
          onTimeout: () {
            subscription.cancel();
            throw TimeoutException('Operation timed out');
          },
        );

        final formatter = NoteFormatter();
        logger.info(formatter.formatNote(note));
        return ExitCode.success.code;
      } catch (e) {
        await subscription.cancel();
        rethrow;
      }
    } on FormatException {
      logger.err('Invalid note ID format');
      return ExitCode.usage.code;
    } on TimeoutException catch (e) {
      logger.err(e.toString());
      return ExitCode.software.code;
    } catch (e) {
      logger.err(e.toString());
      return ExitCode.software.code;
    }
  }
}
