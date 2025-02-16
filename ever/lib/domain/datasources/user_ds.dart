import '../entities/user.dart';
import 'base_ds.dart';

/// Data source interface for User operations
abstract class UserDataSource extends BaseDataSource<User> {
  /// Register a new user
  Future<void> register(String username);
  
  /// Get currently authenticated user info
  Future<void> getCurrentUser();
  
  /// Obtain access token using user secret
  /// This is idempotent - multiple concurrent calls will return the same result
  Future<void> obtainToken(String userSecret);

  /// Initialize the data source
  /// Loads cached credentials and sets up token refresh handling
  Future<void> initialize();

  /// Sign out user and clear cached credentials
  Future<void> signOut();

  /// Execute an API call with automatic token refresh on 401/403
  /// T is the expected return type
  /// apiCall: The actual API call to make
  /// onRefreshSuccess: Optional callback when token is refreshed
  Future<T> executeWithRefresh<T>(
    Future<T> Function() apiCall,
    Future<void> Function()? onRefreshSuccess,
  );

  /// Check if a token refresh is in progress
  bool get isRefreshing;

  /// Get the cached user secret if any
  Future<String?> get cachedUserSecret;

  /// Get the cached access token if any
  Future<String?> get cachedAccessToken;

  /// Get the token expiration time if any
  Future<DateTime?> get tokenExpiresAt;
}
