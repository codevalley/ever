import 'package:ansi_styles/ansi_styles.dart';

import '../../../domain/entities/user.dart';
import 'base.dart';

/// Formatter for user information
class UserFormatter extends OutputFormatter<User> {
  @override
  String format(User user) {
    final createdAt = user.createdAt.toLocal();
    
    return '''
👤 User Information:
Username: ${AnsiStyles.bold(user.username)}
Created: ${AnsiStyles.dim(createdAt.toString())}
${user.userSecret != null ? '''
🔑 Secret: ${AnsiStyles.yellow(user.userSecret!)}
⚠️  ${AnsiStyles.yellow('Save this secret! You\'ll need it to log in.')}
''' : ''}''';
  }
} 