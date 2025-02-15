/// Represents a user in the system
class User {
  final String id;
  final String username;
  final String userSecret;

  const User({
    required this.id,
    required this.username,
    required this.userSecret,
  });
}
