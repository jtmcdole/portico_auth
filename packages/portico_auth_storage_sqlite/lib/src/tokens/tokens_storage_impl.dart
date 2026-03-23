import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _refreshTokenMarker = '%REFRESH_TOKENS%';

const _refreshTokens =
    '''
CREATE TABLE IF NOT EXISTS $_refreshTokenMarker (
    serial TEXT,
    user_id TEXT,
    name TEXT,
    initial_time TEXT,
    last_time TEXT,
    counter INTEGER,
    PRIMARY KEY (serial, user_id)
) WITHOUT ROWID
''';

/// An adapter for [AuthTokensStorageAdapter] using a SQLite backend.
///
/// Remember to await the [initialize] call to ensure the table is created.
class AuthTokensSqlite implements AuthTokensStorageAdapter {
  /// The SQLite database connection.
  final Database database;

  /// The name of the table used for refresh tokens.
  final String tableName;

  /// Creates a new [AuthTokensSqlite].
  AuthTokensSqlite(this.database, {this.tableName = 'RefreshTokens'});

  /// Must be called to initialized the table.
  Future<void> initialize() {
    return database.execute(
      _refreshTokens.replaceFirst(_refreshTokenMarker, tableName),
    );
  }

  /// Deletes the refresh token for the given [serial] and [userId] so that
  /// it cannot be used again for authentication.
  @override
  Future<void> invalidateRefreshToken({
    required String serial,
    required String userId,
  }) async {
    await database.delete(
      tableName,
      where: 'serial = ? AND user_id = ?',
      whereArgs: [serial, userId],
    );
  }

  @override
  Future<List<String>> invalidateAllRefreshTokens({
    required String userId,
  }) async {
    final result = await database.query(
      tableName,
      columns: ['serial'],
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    final serials = [...result.map((row) => row['serial'] as String)];
    if (serials.isNotEmpty) {
      await database.delete(
        tableName,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    }
    return serials;
  }

  /// Record a new refresh token for authenticating the [userId].
  @override
  Future<void> recordRefreshToken({
    required String serial,
    required String userId,
    required DateTime initial,
    required DateTime lastUpdate,
    required num counter,
    required String name,
  }) async {
    await database.insert(tableName, {
      'serial': serial,
      'user_id': userId,
      'name': name,
      'initial_time': initial.toIso8601String(),
      'last_time': lastUpdate.toIso8601String(),
      'counter': counter,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get the refresh counters for the [serial] and [userId], of which their
  /// should be either 1 or none.
  @override
  Future<List<num>> getRefreshTokenCounter({
    required String serial,
    required String userId,
  }) async {
    final query = await database.query(
      tableName,
      columns: ['serial', 'user_id', 'counter'],
      where: 'serial = ? AND user_id = ?',
      whereArgs: [serial, userId],
    );

    final counters = <num>[];
    for (var report in query) {
      counters.add(report['counter'] as num);
    }
    return counters;
  }

  /// Record the new counter for [serial] and [userId].
  @override
  Future<void> updateRefreshTokenCounter({
    required String serial,
    required String userId,
    required DateTime lastUpdate,
    required num counter,
  }) async {
    await database.update(
      tableName,
      {'last_time': lastUpdate.toIso8601String(), 'counter': counter},
      where: 'serial = ? AND user_id = ?',
      whereArgs: [serial, userId],
    );
  }
}
