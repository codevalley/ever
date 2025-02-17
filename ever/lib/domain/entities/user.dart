/// Domain entity representing a user
class User {
  final String id;
  final String username;
  final String? userSecret;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    required this.username,
    this.userSecret,
    required this.createdAt,
    this.updatedAt,
  });

  /// Creates a copy of this User with the given fields replaced with new values
  User copyWith({
    String? id,
    String? username,
    String? userSecret,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      userSecret: userSecret ?? this.userSecret,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          username == other.username &&
          userSecret == other.userSecret &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      username.hashCode ^
      userSecret.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
}
