import '../entities/user.dart';
import 'base_ds.dart';

/// Data source interface for User operations
abstract class UserDataSource extends BaseDataSource<User> {
  /// Register a new user
  /// Returns a Stream that emits the registered User
  /// Emits error if registration fails
  Stream<User> register(String username);
  
  /// Get currently authenticated user info
  /// Returns a Stream that emits the current User
  /// Emits error if user is not authenticated or not found
  Stream<User> getCurrentUser();
  
  /// Obtain access token using user secret
  /// Returns a Stream that emits the access token
  /// This is idempotent - multiple concurrent calls will return the same result
  /// Emits error if token acquisition fails
  Stream<String> obtainToken(String userSecret);

  /// Initialize the data source
  /// Loads cached credentials and sets up token refresh handling
  @override
  Future<void> initialize();

  /// Sign out user and clear cached credentials
  /// Returns a Stream that completes when sign out is done
  /// Emits error if sign out fails
  Stream<void> signOut();

  /// Execute an API call with automatic token refresh on 401/403
  /// T is the expected return type
  /// apiCall: The actual API call to make
  /// onRefreshSuccess: Optional callback when token is refreshed
  /// Returns the result of the API call
  /// Emits error if the call fails and token refresh doesn't help
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

  @override
  bool isOperationSupported(String operation) => false;
}
