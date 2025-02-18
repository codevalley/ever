import 'package:ansi_styles/ansi_styles.dart';
import 'base.dart';

/// Formatter for error messages
class ErrorFormatter extends OutputFormatter<String> {
  @override
  String format(String error) {
    return '❌ Error: ${AnsiStyles.red(error)}';
  }
} 