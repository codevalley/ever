import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../../../../domain/entities/note.dart';
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
    var errorOccurred = false;
    StreamSubscription? stateSubscription;
    
    try {
      // Listen to state changes to handle loading and errors
      stateSubscription = presenter.state.listen(
        (state) {
          if (state.error != null && !errorOccurred) {
            errorOccurred = true;
            logger.err(state.error!);
          }
        },
        onError: (e) {
          if (!errorOccurred) {
            errorOccurred = true;
            logger.err(e.toString());
          }
        },
      );
      
      if (isInteractive) {
        try {
          final completer = Completer<Note>();
          StreamSubscription<Note>? noteSubscription;
          
          noteSubscription = presenter.getNote(id).listen(
            (note) {
              if (!completer.isCompleted) {
                completer.complete(note);
              }
            },
            onError: (e) {
              if (!completer.isCompleted) {
                if (!errorOccurred) {
                  errorOccurred = true;
                  logger.err(e.toString());
                }
                completer.completeError(e);
              }
            },
            onDone: () {
              if (!completer.isCompleted && !errorOccurred) {
                errorOccurred = true;
                final error = Exception('Note not found');
                logger.err(error.toString());
                completer.completeError(error);
              }
            },
          );

          try {
            final note = await completer.future.timeout(
              Duration(seconds: 10),
              onTimeout: () {
                noteSubscription?.cancel();
                throw TimeoutException('Operation timed out');
              },
            );
            
            stdout.write('Current content:\n${note.content}\n');
            stdout.write('New content (press Ctrl+D when done, empty line to keep current):\n');
            final contentInput = await _readMultilineInput();
            content = contentInput.isNotEmpty ? contentInput : null;
            
            await noteSubscription.cancel();
          } catch (e) {
            await noteSubscription.cancel();
            if (!errorOccurred) {
              errorOccurred = true;
              logger.err(e.toString());
            }
            return ExitCode.software.code;
          }
        } catch (e) {
          if (!errorOccurred) {
            errorOccurred = true;
            logger.err(e.toString());
          }
          return ExitCode.software.code;
        }
      } else {
        content = argResults?['content'] as String?;
        
        if (content == null) {
          throw UsageException(
            'Content must be provided.',
            usage,
          );
        }
      }

      final updateCompleter = Completer<void>();
      StreamSubscription? updateSubscription;
      
      try {
        updateSubscription = presenter.state.listen(
          (state) {
            if (state.error != null && !errorOccurred) {
              errorOccurred = true;
              logger.err(state.error!);
              if (!updateCompleter.isCompleted) {
                updateCompleter.completeError(state.error!);
              }
            }
            // Complete when loading finishes with no error
            if (!state.isLoading && state.error == null && !updateCompleter.isCompleted) {
              updateCompleter.complete();
            }
          },
          onError: (e) {
            if (!errorOccurred) {
              errorOccurred = true;
              logger.err(e.toString());
            }
            if (!updateCompleter.isCompleted) {
              updateCompleter.completeError(e);
            }
          },
        );

        await presenter.updateNote(id, content: content);
        
        try {
          await updateCompleter.future.timeout(
            Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Update operation timed out');
            },
          );
          logger.success('Note updated successfully.');
          return ExitCode.success.code;
        } catch (e) {
          if (!errorOccurred) {
            errorOccurred = true;
            logger.err(e.toString());
          }
          return ExitCode.software.code;
        } finally {
          await updateSubscription.cancel();
        }
      } catch (e) {
        await updateSubscription?.cancel();
        if (!errorOccurred) {
          errorOccurred = true;
          logger.err(e.toString());
        }
        return ExitCode.software.code;
      }
    } finally {
      await stateSubscription?.cancel();
    }
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