/// Base class for all authentication-related exceptions.
abstract class AuthException implements Exception {
  /// A message describing the error.
  final String message;

  /// Creates a new [AuthException] with the given [message].
  const AuthException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when invalid credentials are provided during login.
class AuthInvalidCredentialsException extends AuthException {
  /// Creates a new [AuthInvalidCredentialsException].
  const AuthInvalidCredentialsException([
    super.message = 'Invalid username or password.',
  ]);
}

/// Thrown when a network error occurs during authentication.
class AuthNetworkException extends AuthException {
  /// Creates a new [AuthNetworkException].
  const AuthNetworkException([
    super.message = 'A network error occurred. Please check your connection.',
  ]);
}

/// Thrown when an unknown error occurs during authentication.
class AuthUnknownException extends AuthException {
  /// Creates a new [AuthUnknownException].
  const AuthUnknownException([super.message = 'An unknown error occurred.']);
}

/// Thrown when the server returns an unexpected error.
class AuthServerException extends AuthException {
  /// The HTTP status code returned by the server, if available.
  final int? statusCode;

  /// Creates a new [AuthServerException].
  const AuthServerException(super.message, {this.statusCode});
}

/// Thrown when a user already exists during registration.
class AuthUserAlreadyExistsException extends AuthException {
  /// Creates a new [AuthUserAlreadyExistsException].
  const AuthUserAlreadyExistsException([
    super.message = 'A user with this identifier already exists.',
  ]);
}

/// Thrown when an authentication operation is attempted while unauthenticated.
class AuthNotAuthenticatedException extends AuthException {
  /// Creates a new [AuthNotAuthenticatedException].
  const AuthNotAuthenticatedException([
    super.message = 'User is not authenticated.',
  ]);
}
