import '../entities/user.dart';
import 'base_repository.dart';

/// Repository interface for User operations
abstract class UserRepository extends BaseRepository<User> {
  /// Authenticate user with credentials
  void authenticate(String username, String password);
  
  /// Register a new user
  void register(String username, String password);
  
  /// Get currently authenticated user
  void getCurrentUser();
  
  /// Sign out current user
  void signOut();
  
  /// Update user profile
  void updateProfile(User user);
  
  /// Check if user is authenticated
  bool get isAuthenticated;
  
  /// Get current authentication token if any
  String? get currentToken;
}
