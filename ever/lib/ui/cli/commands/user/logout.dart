
import '../base.dart';

/// Command for user logout
class LogoutCommand extends EverCommand {
  @override
  final name = 'logout';
  
  @override
  final description = 'Logout current user';

  LogoutCommand({
    required super.presenter,
    super.logger,
  });

  @override
  Future<void> execute() async {
    // Confirm logout
    final confirm = logger.confirm('Are you sure you want to logout?');
    if (!confirm) {
      logger.info('Logout cancelled');
      return;
    }

    // Logout user
    await presenter.logout();

    // Wait for state to update
    await for (final state in presenter.state) {
      if (!state.isLoading) {
        if (state.currentUser == null) {
          logger.success('Logged out successfully');
          break;
        } else if (state.error != null) {
          // Error already handled by base command
          break;
        }
      }
    }
  }
} 