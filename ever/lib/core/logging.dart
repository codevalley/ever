import 'dart:io';

/// Log levels for the application
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Configuration for logging
class LogConfig {
  /// Whether logging is enabled
  final bool enabled;
  
  /// Minimum log level to show
  final LogLevel minLevel;
  
  /// Whether to include timestamps in logs
  final bool showTimestamp;
  
  /// Whether to include log level in logs
  final bool showLevel;

  const LogConfig({
    this.enabled = false,
    this.minLevel = LogLevel.info,
    this.showTimestamp = true,
    this.showLevel = true,
  });
}

/// Global logging configuration
LogConfig _config = const LogConfig();

/// Initialize logging with the given configuration
void initLogging(LogConfig config) {
  _config = config;
}

/// Log a debug message
void dlog(String message, [String? tag]) {
  _log(LogLevel.debug, message, tag);
}

/// Log an info message
void ilog(String message, [String? tag]) {
  _log(LogLevel.info, message, tag);
}

/// Log a warning message
void wlog(String message, [String? tag]) {
  _log(LogLevel.warning, message, tag);
}

/// Log an error message
void elog(String message, [String? tag]) {
  _log(LogLevel.error, message, tag);
}

/// Internal logging function
void _log(LogLevel level, String message, [String? tag]) {
  if (!_config.enabled || level.index < _config.minLevel.index) return;

  final buffer = StringBuffer();
  
  if (_config.showTimestamp) {
    final now = DateTime.now();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.microsecond.toString().padLeft(6, '0')}';
    buffer.write('$time  ');
  }
  
  if (_config.showLevel) {
    final levelStr = switch (level) {
      LogLevel.debug => '[Debug]',
      LogLevel.info => '[Info] ',
      LogLevel.warning => '[Warn] ',
      LogLevel.error => '[Error]',
    };
    buffer.write('$levelStr ');
  }
  
  buffer.write(message);
  buffer.write('\n');

  if (level == LogLevel.error) {
    stderr.write(buffer.toString());
  } else {
    stdout.write(buffer.toString());
  }
}

/// Shorthand for debug log with emoji
void dprint(String message, [String emoji = '🔍']) {
  dlog('$emoji $message');
}

/// Shorthand for error log with emoji
void eprint(String message, [String emoji = '❌']) {
  elog('$emoji $message');
}

/// Shorthand for warning log with emoji
void wprint(String message, [String emoji = '⚠️']) {
  wlog('$emoji $message');
}

/// Shorthand for info log with emoji
void iprint(String message, [String emoji = 'ℹ️']) {
  ilog('$emoji $message');
} 