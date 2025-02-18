import 'logging.dart';

/// Application configuration
class AppConfig {
  /// Whether the app is running in debug mode
  final bool isDebug;
  
  /// Logging configuration
  final LogConfig logging;
  
  /// API configuration
  final String apiUrl;
  
  const AppConfig({
    required this.isDebug,
    required this.logging,
    required this.apiUrl,
  });
  
  /// Development configuration
  static const development = AppConfig(
    isDebug: true,
    logging: LogConfig(
      enabled: true,
      minLevel: LogLevel.debug,
      showTimestamp: true,
      showLevel: true,
    ),
    apiUrl: 'http://localhost:3000',
  );
  
  /// Production configuration
  static const production = AppConfig(
    isDebug: false,
    logging: LogConfig(
      enabled: false,
      minLevel: LogLevel.error,
      showTimestamp: true,
      showLevel: true,
    ),
    apiUrl: 'https://api.ever.example.com',
  );
  
  /// Test configuration
  static const test = AppConfig(
    isDebug: true,
    logging: LogConfig(
      enabled: true,
      minLevel: LogLevel.debug,
      showTimestamp: false,
      showLevel: true,
    ),
    apiUrl: 'http://localhost:3000',
  );
} 