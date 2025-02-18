import 'package:ansi_styles/ansi_styles.dart';
import 'base.dart';

/// Formatter for success messages
class SuccessFormatter extends OutputFormatter<String> {
  @override
  String format(String message) {
    return '✅ ${AnsiStyles.green(message)}';
  }
} 