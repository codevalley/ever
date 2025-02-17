import 'events.dart';

/// Event when user successfully registers
class UserRegistered extends DomainEvent {
  final dynamic user;
  final String userSecret;

  const UserRegistered(this.user, this.userSecret);
}

/// Event when user registration fails
class RegistrationFailed extends DomainEvent {
  final String message;
  RegistrationFailed(this.message);
}

/// Event when token is obtained
class TokenObtained extends DomainEvent {
  final String token;
  final DateTime expiresAt;

  const TokenObtained(this.token, this.expiresAt);
}

/// Event when token acquisition fails
class TokenAcquisitionFailed extends DomainEvent {
  final String message;
  TokenAcquisitionFailed(this.message);
}

/// Event when token is about to expire
class TokenExpiring extends DomainEvent {
  final Duration timeLeft;
  TokenExpiring(this.timeLeft);
}

/// Event when token has expired
class TokenExpired extends DomainEvent {}

/// Event when token refresh succeeds
class TokenRefreshed extends DomainEvent {
  final String accessToken;
  final DateTime expiresAt;
  TokenRefreshed(this.accessToken, this.expiresAt);
}

/// Event when token refresh fails
class TokenRefreshFailed extends DomainEvent {
  final String error;

  const TokenRefreshFailed(this.error);
}

/// Event when current user info is retrieved
class CurrentUserRetrieved extends DomainEvent {
  final dynamic user;

  const CurrentUserRetrieved(this.user);
}

/// Event when user logs out
class UserLoggedOut extends DomainEvent {
  const UserLoggedOut();
}
