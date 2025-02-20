import '../base.dart';
import 'create.dart';
import 'delete.dart';
import 'list.dart';
import 'update.dart';

/// Group command for note-related operations
class NoteCommand extends EverCommand {
  @override
  final name = 'note';
  
  @override
  final description = 'Note management commands';

  NoteCommand({
    required super.presenter,
    super.logger,
  }) {
    addSubcommand(CreateNoteCommand(presenter: presenter));
    addSubcommand(UpdateNoteCommand(presenter: presenter));
    addSubcommand(DeleteNoteCommand(presenter: presenter));
    addSubcommand(ListNotesCommand(presenter: presenter));
  }

  @override
  Future<int> execute() async {
    // Print usage if no subcommand is provided
    printUsage();
    return ExitCode.success.code;
  }
} 