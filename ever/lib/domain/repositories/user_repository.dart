import '../entities/user.dart';
import 'base_repository.dart';

/// Repository interface for User operations
abstract class UserRepository extends BaseRepository<User> {
  /// Register a new user with username
  /// Returns a Stream of the registered User
  Stream<User> register(String username);
  
  /// Obtain access token using user secret
  /// Returns a Stream that emits the token when obtained
  Stream<String> obtainToken(String userSecret);

  /// Refresh the access token using user secret
  /// Returns a Stream that emits the new token when refreshed
  Stream<String> refreshToken();
  
  /// Get currently authenticated user info
  /// Returns a Stream of the current User
  Stream<User> getCurrentUser();
  
  /// Sign out current user (clear token)
  /// Returns a Stream that completes when sign out is done
  Stream<void> signOut();
  
  /// Check if user has a valid token
  bool get isAuthenticated;
  
  /// Get current access token if any
  String? get currentToken;
  
  /// Get current user secret if any
  String? get currentUserSecret;

  /// Get token expiration time if any
  DateTime? get tokenExpiresAt;
}
