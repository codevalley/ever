import '../entities/user.dart';
import 'base_repository.dart';

/// Repository interface for User operations
abstract class UserRepository extends BaseRepository<User> {
  /// Register a new user with username
  void register(String username);
  
  /// Obtain access token using user secret
  void obtainToken(String userSecret);

  /// Refresh the access token using user secret
  /// This should be called when the current token is about to expire
  void refreshToken();
  
  /// Get currently authenticated user info
  void getCurrentUser();
  
  /// Sign out current user (clear token)
  void signOut();
  
  /// Check if user has a valid token
  bool get isAuthenticated;
  
  /// Get current access token if any
  String? get currentToken;
  
  /// Get current user secret if any
  String? get currentUserSecret;

  /// Get token expiration time if any
  DateTime? get tokenExpiresAt;
}
