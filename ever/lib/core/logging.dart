import 'dart:developer' as developer;

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
    buffer.write('${DateTime.now().toIso8601String()} ');
  }
  
  if (_config.showLevel) {
    buffer.write('[${level.toString().toUpperCase()}] ');
  }
  
  if (tag != null) {
    buffer.write('[$tag] ');
  }
  
  buffer.write(message);

  developer.log(
    buffer.toString(),
    time: DateTime.now(),
    level: level.index,
    name: tag ?? 'EVER',
  );
}

/// Shorthand for debug log with emoji
void dprint(String message, [String emoji = '🔍']) {
  dlog('$emoji $message', 'Debug');
}

/// Shorthand for error log with emoji
void eprint(String message, [String emoji = '❌']) {
  elog('$emoji $message', 'Error');
}

/// Shorthand for warning log with emoji
void wprint(String message, [String emoji = '⚠️']) {
  wlog('$emoji $message', 'Warning');
}

/// Shorthand for info log with emoji
void iprint(String message, [String emoji = 'ℹ️']) {
  ilog('$emoji $message', 'Info');
} 