/// A record containing the password hash and salt.
typedef CredentialHash = ({String hash, String salt});

/// Interface for auth credentials storage.
abstract interface class AuthCredentialsStorageAdapter {
  /// Deletes the user with the given [userId].
  /// Throws [UserDoesNotExistException] if user not found.
  Future<void> deleteUser(String userId);

  /// Creates a new user with the given [userId], [salt], and [hash].
  /// [creationTime] is when the user was first registered.
  Future<void> createUser({
    required String userId,
    required String salt,
    required String hash,
    required DateTime creationTime,
  });

  /// Updates the password for the user with the given [userId].
  Future<void> updatePassword({
    required String userId,
    required String salt,
    required String hash,
  });

  /// Retrieves the password hash and salt for the user with the given [userId].
  /// Throws [UserDoesNotExistException] if user not found.
  Future<CredentialHash> getPasswordHash(String userId);
}
