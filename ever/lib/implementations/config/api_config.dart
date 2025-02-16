/// Configuration for API endpoints and settings
class ApiConfig {
  /// Base URL for the API
  static const baseUrl = 'https://api.friday.com';

  /// API version prefix
  static const apiVersion = 'v1';

  /// Full API base URL with version
  static String get apiBaseUrl => '$baseUrl/$apiVersion';

  /// API endpoints
  static const endpoints = _Endpoints();

  /// Token configuration
  static const tokenConfig = _TokenConfig();

  /// HTTP headers
  static const headers = _Headers();

  /// API request/response keys
  static const keys = _ApiKeys();
}

/// API endpoint paths
class _Endpoints {
  const _Endpoints();

  /// Authentication endpoints
  final auth = const _AuthEndpoints();
}

/// Authentication related endpoints
class _AuthEndpoints {
  const _AuthEndpoints();

  /// Register new user endpoint
  String get register => '/auth/register';

  /// Obtain token endpoint
  String get token => '/auth/token';

  /// Get current user info endpoint
  String get me => '/auth/me';
}

/// Token related configuration
class _TokenConfig {
  const _TokenConfig();

  /// Duration before token expiry when we should refresh
  Duration get refreshThreshold => const Duration(minutes: 5);

  /// Estimated token lifetime
  Duration get tokenLifetime => const Duration(hours: 1);
}

/// Common HTTP headers
class _Headers {
  const _Headers();

  /// Content type for JSON requests
  Map<String, String> get json => {
        'Content-Type': 'application/json',
      };

  /// Headers for authenticated requests
  Map<String, String> withAuth(String token) => {
        ...json,
        'Authorization': 'Bearer $token',
      };
}

/// API request/response keys
class _ApiKeys {
  const _ApiKeys();

  /// Common response keys
  final common = const _CommonKeys();

  /// Authentication related keys
  final auth = const _AuthKeys();

  /// User related keys
  final user = const _UserKeys();
}

/// Common response keys
class _CommonKeys {
  const _CommonKeys();

  /// Response data wrapper key
  String get data => 'data';

  /// Error message key
  String get message => 'message';
}

/// Authentication related keys
class _AuthKeys {
  const _AuthKeys();

  /// User secret key in registration response
  String get userSecret => 'user_secret';

  /// Access token key in token response
  String get accessToken => 'access_token';

  /// Username key in requests
  String get username => 'username';
}

/// User related keys
class _UserKeys {
  const _UserKeys();

  /// User ID key
  String get id => 'id';

  /// User display name key
  String get displayName => 'display_name';

  /// User creation timestamp key
  String get createdAt => 'created_at';

  /// User last modified timestamp key
  String get updatedAt => 'updated_at';
}
