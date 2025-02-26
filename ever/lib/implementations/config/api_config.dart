/// Configuration for API endpoints and settings
class ApiConfig {
  /// Base URL for the API
  static String baseUrl = 'https://api.nyn.sh';

  /// API version prefix
  static const apiVersion = 'v1';

  /// Full API base URL with version
  static String get apiBaseUrl => '$baseUrl/$apiVersion';

  /// Update the base URL
  static void updateBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// API endpoints
  static const endpoints = _Endpoints();

  /// Token configuration
  static const tokenConfig = _TokenConfig();

  /// HTTP headers
  static const headers = _Headers();

  /// API request/response keys
  static const keys = _ApiKeys();

  /// Operation names
  static const operations = _Operations();
}

/// API endpoint paths
class _Endpoints {
  const _Endpoints();

  /// Authentication endpoints
  final auth = const _AuthEndpoints();

  /// Note endpoints
  final note = const _NoteEndpoints();

  /// Task endpoints
  final task = const _TaskEndpoints();
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

/// Note related endpoints
class _NoteEndpoints {
  const _NoteEndpoints();

  /// Create note endpoint
  String get create => '/notes';

  /// Update note endpoint
  String note(String id) => '/notes/$id';

  /// Delete note endpoint
  String delete(String id) => '/notes/$id';

  /// List notes endpoint
  String get list => '/notes';

  /// Process note endpoint
  String process(String id) => '/notes/$id/process';

  /// Add attachment endpoint
  String attachment(String id) => '/notes/$id/attachments';
}

/// Task related endpoints
class _TaskEndpoints {
  const _TaskEndpoints();

  /// Create task endpoint
  String get create => '/tasks';

  /// Task operations endpoint
  String task(String id) => '/tasks/$id';

  /// List tasks endpoint
  String get list => '/tasks';

  /// Process task endpoint
  String process(String id) => '/tasks/$id/process';
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

  /// Note related keys
  final note = const _NoteKeys();
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

  /// User creation timestamp key
  String get createdAt => 'created_at';

  /// User last modified timestamp key
  String get updatedAt => 'updated_at';
}

/// Note related keys
class _NoteKeys {
  const _NoteKeys();

  /// Note ID key
  String get id => 'id';

  /// Note title key
  String get title => 'title';

  /// Note content key
  String get content => 'content';

  /// Note user ID key
  String get userId => 'user_id';

  /// Note creation timestamp key
  String get createdAt => 'created_at';

  /// Note last modified timestamp key
  String get updatedAt => 'updated_at';

  /// Note attachments key
  String get attachments => 'attachments';

  /// Note processing status key
  String get processingStatus => 'processing_status';

  /// Note enrichment data key
  String get enrichmentData => 'enrichment_data';

  /// Note attachment type key
  String get attachmentType => 'type';

  /// Note attachment URL key
  String get attachmentUrl => 'url';
}

/// Operation names for events and logging
class _Operations {
  const _Operations();

  /// Authentication related operations
  final auth = const _AuthOperations();

  /// Note related operations
  final note = const _NoteOperations();

  /// Task related operations
  final task = const _TaskOperations();
}

/// Authentication related operation names
class _AuthOperations {
  const _AuthOperations();

  /// Register operation name
  String get register => 'auth_register';

  /// Obtain token operation name
  String get obtainToken => 'auth_obtain_token';

  /// Get current user operation name
  String get getCurrentUser => 'auth_get_current_user';

  /// Sign out operation name
  String get signOut => 'auth_sign_out';

  /// Refresh token operation name
  String get refreshToken => 'auth_refresh_token';

  /// Generic auth operation name
  String get generic => 'auth_operation';
}

/// Note related operation names
class _NoteOperations {
  const _NoteOperations();

  /// Create note operation name
  String get create => 'note_create';

  /// Update note operation name
  String get update => 'note_update';

  /// Delete note operation name
  String get delete => 'note_delete';

  /// List notes operation name
  String get list => 'note_list';

  /// Read note operation name
  String get read => 'note_read';

  /// Search notes operation name
  String get search => 'note_search';

  /// Process note operation name
  String get process => 'note_process';

  /// Add attachment operation name
  String get addAttachment => 'note_add_attachment';

  /// Generic note operation name
  String get generic => 'note_operation';
}

/// Task related operation names
class _TaskOperations {
  const _TaskOperations();

  /// Create task operation name
  String get create => 'task_create';

  /// Update task operation name
  String get update => 'task_update';

  /// Delete task operation name
  String get delete => 'task_delete';

  /// List tasks operation name
  String get list => 'task_list';

  /// Read task operation name
  String get read => 'task_read';
}
