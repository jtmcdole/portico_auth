import 'credentials_storage_adapter.dart';
import 'credential_exceptions.dart';

/// In-memory implementation of [AuthCredentialsStorageAdapter].
final class AuthCredentialsInMemoryStorage
    implements AuthCredentialsStorageAdapter {
  final Map<String, UserData> _users = {};

  /// Returns an unmodifiable map of users in memory.
  Map<String, UserData> get users => Map.unmodifiable(_users);

  /// Clears all users from memory.
  void clear() => _users.clear();

  /// Deletes the user with the given [userId] from memory.
  ///
  /// Throws [UserDoesNotExistException] if the user is not found.
  @override
  Future<void> deleteUser(String userId) async {
    if (!_users.containsKey(userId)) throw UserDoesNotExistException(userId);
    _users.remove(userId);
  }

  /// Creates a new user in memory with the given [userId], [salt], and [hash].
  ///
  /// Throws [UserAlreadyExistsException] if a user with the same userId exists.
  @override
  Future<void> createUser({
    required String userId,
    required String salt,
    required String hash,
    required DateTime creationTime,
  }) async {
    if (_users.containsKey(userId)) throw UserAlreadyExistsException(userId);
    _users[userId] = UserData(
      salt: salt,
      hash: hash,
      creationTime: creationTime,
    );
  }

  /// Updates the password hash and salt for the user with [userId] in memory.
  ///
  /// Throws [UserDoesNotExistException] if the user is not found.
  @override
  Future<void> updatePassword({
    required String userId,
    required String salt,
    required String hash,
  }) async {
    final user = _users[userId];
    if (user == null) throw UserDoesNotExistException(userId);
    _users[userId] = UserData(
      salt: salt,
      hash: hash,
      creationTime: user.creationTime,
    );
  }

  /// Retrieves the password hash and salt for the user with [userId] from memory.
  ///
  /// Throws [UserDoesNotExistException] if the user is not found.
  @override
  Future<CredentialHash> getPasswordHash(String userId) async {
    final user = _users[userId];
    if (user == null) throw UserDoesNotExistException(userId);
    return (salt: user.salt, hash: user.hash);
  }
}

/// Internal data class representing a user in memory.
class UserData {
  /// The user's salt (base64 encoded).
  final String salt;

  /// The user's password hash (base64 encoded).
  final String hash;

  /// When the user was created.
  final DateTime creationTime;

  /// Creates a new [UserData].
  UserData({
    required this.salt,
    required this.hash,
    required this.creationTime,
  });
}
