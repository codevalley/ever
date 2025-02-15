import '../entities/user.dart';
import 'events.dart';

/// Event when user successfully logs in
class UserLoggedIn extends DomainEvent {
  final User user;
  UserLoggedIn(this.user);
}

/// Event when user logs out
class UserLoggedOut extends DomainEvent {}

/// Event when authentication fails
class AuthenticationFailed extends DomainEvent {
  final String message;
  AuthenticationFailed(this.message);
}

/// Event when user session expires
class SessionExpired extends DomainEvent {}

/// Event when user profile is updated
class UserProfileUpdated extends DomainEvent {
  final User user;
  UserProfileUpdated(this.user);
}

/// Event when user registration is completed
class UserRegistered extends DomainEvent {
  final User user;
  UserRegistered(this.user);
}
