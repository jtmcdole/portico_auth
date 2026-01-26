/// Thrown when a refresh token is invalid or expired.
class RefreshTokenInvalid implements Exception {
  /// The reason why the token is invalid.
  final String reason;

  /// Creates a new [RefreshTokenInvalid] with the given [reason].
  const RefreshTokenInvalid(this.reason);

  // coverage:ignore-start
  @override
  String toString() => '$RefreshTokenInvalid: $reason';
  // coverage:ignore-end
}

/// Thrown when an access token is invalid or expired.
class AccessTokenInvalid implements Exception {
  /// The reason why the token is invalid.
  final String reason;

  /// Creates a new [AccessTokenInvalid] with the given [reason].
  const AccessTokenInvalid(this.reason);

  // coverage:ignore-start
  @override
  String toString() => '$AccessTokenInvalid: $reason';
  // coverage:ignore-end
}
