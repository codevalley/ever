import '../entities/user.dart';
import 'base_ds.dart';

/// Data source interface for User operations
abstract class UserDataSource extends BaseDataSource<User> {
  /// Authenticate user with credentials
  void authenticate(String username, String password);
  
  /// Get currently authenticated user
  void getCurrentUser();
  
  /// Sign out current user
  void signOut();
}
