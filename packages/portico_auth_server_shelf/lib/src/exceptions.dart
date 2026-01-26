/// Thrown when a user is authenticated but lacks the required permissions
/// for a specific resource or action.
class ForbiddenException implements Exception {
  /// A message describing the specific permission failure.
  final String message;
  ForbiddenException(this.message);
  @override
  String toString() => 'Forbidden: $message';
}

/// Thrown when a request lacks valid authentication credentials.
class UnauthorizedException implements Exception {
  /// A message describing the authentication failure.
  final String message;
  UnauthorizedException(this.message);
  @override
  String toString() => 'Unauthorized: $message';
}
