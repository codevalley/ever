import 'package:isar/isar.dart';

/// Isar collection for storing authentication credentials
@collection
class AuthCredentials {
  /// Isar ID - We use ID 1 as we only ever need one instance of credentials
  /// This is a common pattern in Isar when you need a singleton object
  /// The ID is used as a primary key to ensure we only have one record
  Id id = 1;
  
  /// User secret obtained during registration
  /// Used to obtain new access tokens
  String? userSecret;

  /// Current access token for API calls
  String? accessToken;

  /// When the current token expires
  DateTime? tokenExpiresAt;

  /// Check if the token is expired or about to expire
  /// [threshold] is how close to expiration we consider it "expired"
  bool isExpiredOrExpiring(Duration threshold) {
    if (tokenExpiresAt == null) return true;
    return tokenExpiresAt!.isBefore(DateTime.now().add(threshold));
  }

  /// Create a new instance with updated token information
  AuthCredentials copyWithToken({
    required String accessToken,
    required DateTime expiresAt,
  }) {
    return AuthCredentials()
      ..id = id
      ..userSecret = userSecret
      ..accessToken = accessToken
      ..tokenExpiresAt = expiresAt;
  }

  /// Create a new instance with updated user secret
  AuthCredentials copyWithSecret({
    required String userSecret,
  }) {
    return AuthCredentials()
      ..id = id
      ..userSecret = userSecret
      ..accessToken = accessToken
      ..tokenExpiresAt = tokenExpiresAt;
  }
}
