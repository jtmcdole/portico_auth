/// Provides access to storage for authentication tokens.
abstract interface class AuthTokensStorageAdapter {
  /// Deletes the refresh token for the given [serial] and [userId] so that
  /// it cannot be used again for authentication.
  Future<void> invalidateRefreshToken({
    required String serial,
    required String userId,
  });

  /// Record a new refresh token for authenticating the [userId].
  Future<void> recordRefreshToken({
    required String serial,
    required String userId,
    required DateTime initial,
    required DateTime lastUpdate,
    required num counter,
    required String name,
  });

  /// Get the refresh counters for the [serial] and [userId], of which their
  /// should be either 1 or none.
  Future<List<num>> getRefreshTokenCounter({
    required String serial,
    required String userId,
  });

  /// Record the new counter for [serial] and [userId].
  Future<void> updateRefreshTokenCounter({
    required String serial,
    required String userId,
    required DateTime lastUpdate,
    required num counter,
  });
}
