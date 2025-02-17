import 'package:isar/isar.dart';

/// Model for storing authentication credentials
@Collection()
class AuthCredentials {
  /// Primary key for Isar
  Id id = 1; // Fixed ID since we only store one instance

  /// User secret for obtaining tokens
  String? userSecret;

  /// Current access token
  String? accessToken;

  /// When the current token expires
  DateTime? tokenExpiresAt;

  /// Create a copy with updated token information
  AuthCredentials copyWithToken({
    required String accessToken,
    required DateTime expiresAt,
  }) {
    final copy = AuthCredentials()
      ..id = id
      ..userSecret = userSecret
      ..accessToken = accessToken
      ..tokenExpiresAt = expiresAt;
    return copy;
  }

  /// Create a copy with updated user secret
  AuthCredentials copyWithSecret({
    required String userSecret,
  }) {
    final copy = AuthCredentials()
      ..id = id
      ..userSecret = userSecret
      ..accessToken = accessToken
      ..tokenExpiresAt = tokenExpiresAt;
    return copy;
  }

  /// Check if token is expired or will expire soon
  bool isExpiredOrExpiring(Duration threshold) {
    if (tokenExpiresAt == null) return true;
    final now = DateTime.now();
    return now.isAfter(tokenExpiresAt!) ||
           now.add(threshold).isAfter(tokenExpiresAt!);
  }
}
