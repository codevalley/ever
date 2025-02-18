
import '../../formatters/user.dart';
import '../base.dart';

/// Command for viewing user profile
class ProfileCommand extends EverCommand {
  @override
  final name = 'profile';
  
  @override
  final description = 'View current user profile';

  ProfileCommand({
    required super.presenter,
    super.logger,
  });

  @override
  Future<void> execute() async {
    // Get current user
    await presenter.getCurrentUser();

    // Wait for state to update
    await for (final state in presenter.state) {
      if (!state.isLoading) {
        if (state.currentUser != null) {
          logger.info(UserFormatter().format(state.currentUser!));
          break;
        } else if (state.error != null) {
          // Error already handled by base command
          break;
        } else {
          logger.warn('Not logged in');
          break;
        }
      }
    }
  }
} 