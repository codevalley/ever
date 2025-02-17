/// Configuration for error messages across the application
class ErrorMessages {
  /// Authentication related error messages
  static const auth = _AuthErrors();
  
  /// User related error messages
  static const user = _UserErrors();
  
  /// Operation related error messages
  static const operation = _OperationErrors();
}

/// Authentication related error messages
class _AuthErrors {
  const _AuthErrors();

  /// Token related errors
  String get noToken => 'No access token available';
  String get tokenExpired => 'Access token has expired';
  String get noUserSecret => 'No user secret available for token refresh';
  String get tokenRefreshFailed => 'Failed to refresh access token';
  String get invalidCredentials => 'Invalid credentials provided';

  /// Registration errors
  String get registrationFailed => 'Registration failed';
  String get usernameTaken => 'Username is already taken';
  String get invalidUsername => 'Invalid username format';

  /// General auth errors
  String get unauthorized => 'Unauthorized access';
  String get sessionExpired => 'Session has expired';
  String get authenticationFailed => 'Authentication failed';
}

/// User related error messages
class _UserErrors {
  const _UserErrors();

  /// User operation errors
  String get userNotFound => 'User not found';
  String get invalidUserData => 'Invalid user data provided';
  String get userUpdateFailed => 'Failed to update user information';
  
  /// Operation support errors
  String get createNotSupported => 'Create operation not supported for User entity';
  String get updateNotSupported => 'Update operation not supported for User entity';
  String get deleteNotSupported => 'Delete operation not supported for User entity';
  String get listNotSupported => 'List operation not supported for User entity';
  String get readNotSupported => 'Read operation not supported for User entity';
}

/// General operation error messages
class _OperationErrors {
  const _OperationErrors();

  /// Data errors
  String get unexpectedDataType => 'Unexpected data type from data source';
  String get invalidResponse => 'Invalid response format';
  String get dataNotFound => 'Requested data not found';

  /// Network errors
  String get networkError => 'Network connection error';
  String get serverError => 'Server error occurred';
  String get timeoutError => 'Operation timed out';

  /// State errors
  String get invalidState => 'Invalid operation state';
  String get operationInProgress => 'Operation already in progress';
  String get operationFailed => 'Operation failed';
} 