/// Thrown when a user already exists during registration.
class UserAlreadyExistsException implements Exception {
  final String userId;
  const UserAlreadyExistsException(this.userId);

  @override
  String toString() =>
      '$UserAlreadyExistsException: User with userId $userId already exists.';
}

/// Thrown when a user does not exists.
class UserDoesNotExistException implements Exception {
  final String userId;
  const UserDoesNotExistException(this.userId);
  @override
  String toString() =>
      '$UserDoesNotExistException: User with userId $userId does not exists.';
}

/// Thrown when credentials verification fails.
class InvalidCredentialsException implements Exception {
  final String message;
  const InvalidCredentialsException([
    this.message = 'Invalid userId or password',
  ]);
  @override
  String toString() => '$InvalidCredentialsException: $message.';
}
