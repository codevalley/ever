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
      StreamSubscription<Note>? subscription;
      StreamSubscription? stateSubscription;
      var errorOccurred = false;
      
      // Listen to state changes to handle loading and errors
      stateSubscription = presenter.state.listen(
        (state) {
          if (state.error != null && !errorOccurred) {
            errorOccurred = true;
            logger.err('Failed to read note: ${state.error}');
          }
        },
        onError: (e) {
          if (!errorOccurred) {
            errorOccurred = true;
            logger.err('Failed to read note: $e');
          }
        },
      );
      
      subscription = presenter.getNote(id).listen(
        (note) {
          if (!completer.isCompleted) {
            completer.complete(note);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            if (!errorOccurred) {
              errorOccurred = true;
              logger.err('Failed to read note: $e');
            }
            completer.completeError(e);
          }
        },
        onDone: () {
          if (!completer.isCompleted && !errorOccurred) {
            errorOccurred = true;
            final error = Exception('Note not found');
            logger.err('Failed to read note: $error');
            completer.completeError(error);
          }
        },
      );

      try {
        final note = await completer.future.timeout(
          Duration(seconds: 10),
          onTimeout: () {
            subscription?.cancel();
            stateSubscription?.cancel();
            throw TimeoutException('Operation timed out');
          },
        );

        final formatter = NoteFormatter();
        logger.info(formatter.formatNote(note));
        await subscription.cancel();
        await stateSubscription.cancel();
        return ExitCode.success.code;
      } catch (e) {
        await subscription.cancel();
        await stateSubscription.cancel();
        if (!errorOccurred) {
          logger.err('Failed to read note: $e');
        }
        return ExitCode.software.code;
      }
    } on FormatException {
      logger.err('Invalid note ID format');
      return ExitCode.usage.code;
    } on TimeoutException catch (e) {
      logger.err(e.toString());
      return ExitCode.software.code;
    } catch (e) {
      if (!e.toString().contains('Note not found') && !e.toString().contains('Failed to read note')) {
        logger.err('Failed to read note: $e');
      }
      return ExitCode.software.code;
    }
  }
}
