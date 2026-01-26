import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _credentialsTableMarker = '%CREDENTIALS%';

const _credentialsSchema =
    '''
CREATE TABLE IF NOT EXISTS $_credentialsTableMarker (
    user_id TEXT PRIMARY KEY,
    salt TEXT,
    hash TEXT,
    creation_time TEXT
) WITHOUT ROWID
''';

/// An adapter for [AuthCredentialsStorageAdapter] using a SQLite backend.
///
/// Remember to await the [initialize] call to ensure the table is created.
class AuthCredentialsSqlite implements AuthCredentialsStorageAdapter {
  /// The SQLite database connection.
  final Database database;

  /// The name of the table used for credentials.
  final String tableName;

  /// Creates a new [AuthCredentialsSqlite].
  AuthCredentialsSqlite(this.database, {this.tableName = 'Credentials'});

  /// Must be called to initialize the table.
  Future<void> initialize() {
    return database.execute(
      _credentialsSchema.replaceFirst(_credentialsTableMarker, tableName),
    );
  }

  /// Deletes the user with the given [userId].
  ///
  /// Throws [UserDoesNotExistException] if the user is not found.
  @override
  Future<void> deleteUser(String userId) async {
    final count = await database.delete(
      tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (count == 0) {
      throw UserDoesNotExistException(userId);
    }
  }

  /// Creates a new user with the given [userId], [salt], and [hash].
  /// [creationTime] is when the user was first registered.
  ///
  /// Throws [UserAlreadyExistsException] if a user with the same userId exists.
  @override
  Future<void> createUser({
    required String userId,
    required String salt,
    required String hash,
    required DateTime creationTime,
  }) async {
    try {
      await database.insert(tableName, {
        'user_id': userId,
        'salt': salt,
        'hash': hash,
        'creation_time': creationTime.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw UserAlreadyExistsException(userId);
      }
      rethrow;
    }
  }

  /// Updates the password for the user with the given [userId].
  ///
  /// Throws [UserDoesNotExistException] if the user is not found.
  @override
  Future<void> updatePassword({
    required String userId,
    required String salt,
    required String hash,
  }) async {
    final count = await database.update(
      tableName,
      {'salt': salt, 'hash': hash},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (count == 0) {
      throw UserDoesNotExistException(userId);
    }
  }

  /// Retrieves the password hash and salt for the user with the given [userId].
  /// Throws [UserDoesNotExistException] if user not found.
  @override
  Future<CredentialHash> getPasswordHash(String userId) async {
    final results = await database.query(
      tableName,
      columns: ['hash', 'salt'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    if (results.isEmpty) {
      throw UserDoesNotExistException(userId);
    }

    final row = results.first;
    return (hash: row['hash'] as String, salt: row['salt'] as String);
  }
}
