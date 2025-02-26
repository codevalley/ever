import 'dart:async';

import '../../formatters/note.dart';
import '../base.dart';
import '../user/login.dart';

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
    // Check if user is authenticated
    bool isAuthenticated = false;
    try {
      // Get the current state once to check authentication
      await for (final state in presenter.state.take(1)) {
        isAuthenticated = state.isAuthenticated;
        break;
      }
    } catch (e) {
      // If we can't get the state, assume not authenticated
      isAuthenticated = false;
    }
    
    if (!isAuthenticated) {
      logger.warn('You need to be logged in to list notes.');
      
      // Ask if they want to login
      final shouldLogin = logger.confirm(
        'Would you like to login now?',
        defaultValue: true,
      );
      
      if (shouldLogin) {
        // Run the login command
        final loginCommand = LoginCommand(presenter: presenter, logger: logger);
        // Execute the login command but don't use its return value
        await loginCommand.execute();
        
        // Check if we're authenticated after login
        bool loginSuccessful = false;
        await for (final state in presenter.state.take(1)) {
          loginSuccessful = state.isAuthenticated;
          break;
        }
        
        // If login failed, return error
        if (!loginSuccessful) {
          logger.err('Login failed');
          return ExitCode.software.code;
        }
      } else {
        logger.err('Must be authenticated to list notes');
        return ExitCode.software.code;
      }
    }
    
    final includeArchived = argResults?['all'] as bool? ?? false;
    
    try {
      final notes = await presenter.listNotes(includeArchived: includeArchived);
      final formatter = NoteFormatter();
      
      logger.info(formatter.formatNoteList(notes));
      return ExitCode.success.code;
    } catch (e) {
      logger.err(e.toString());
      return ExitCode.software.code;
    }
  }
} 