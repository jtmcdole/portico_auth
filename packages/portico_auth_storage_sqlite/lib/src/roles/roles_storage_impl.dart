import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _rolesTableMarker = '%ROLES%';
const _assignmentsTableMarker = '%ASSIGNMENTS%';

const _rolesSchema =
    '''
CREATE TABLE IF NOT EXISTS $_rolesTableMarker (
    name TEXT PRIMARY KEY,
    display_name TEXT,
    description TEXT,
    is_active INTEGER DEFAULT 1
) WITHOUT ROWID
''';

const _assignmentsSchema =
    '''
CREATE TABLE IF NOT EXISTS $_assignmentsTableMarker (
    user_id TEXT,
    role_name TEXT,
    scope TEXT,
    PRIMARY KEY (user_id, role_name, scope),
    FOREIGN KEY (role_name) REFERENCES $_rolesTableMarker (name)
) WITHOUT ROWID
''';

/// An adapter for [AuthRolesStorageAdapter] using a SQLite backend.
class AuthRolesSqlite implements AuthRolesStorageAdapter {
  /// The SQLite database connection.
  final Database database;

  /// The name of the table used for roles.
  final String rolesTableName;

  /// The name of the table used for role assignments.
  final String assignmentsTableName;

  /// Creates a new [AuthRolesSqlite].
  AuthRolesSqlite(
    this.database, {
    this.rolesTableName = 'Roles',
    this.assignmentsTableName = 'RoleAssignments',
  });

  /// Must be called to initialize the tables.
  Future<void> initialize() async {
    await database.execute('PRAGMA foreign_keys = ON');
    await database.execute(
      _rolesSchema.replaceFirst(_rolesTableMarker, rolesTableName),
    );
    await database.execute(
      _assignmentsSchema
          .replaceFirst(_assignmentsTableMarker, assignmentsTableName)
          .replaceFirst(_rolesTableMarker, rolesTableName),
    );
  }

  /// Creates a new role in SQLite.
  ///
  /// Throws [RoleAlreadyExistsException] if a role with the same name exists.
  @override
  Future<void> createRole(Role role) async {
    try {
      await database.insert(rolesTableName, {
        'name': role.name,
        'display_name': role.displayName,
        'description': role.description,
        'is_active': role.isActive ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw RoleAlreadyExistsException(role.name);
      }
      rethrow;
    }
  }

  /// Updates an existing role in SQLite.
  ///
  /// Throws [RoleDoesNotExistException] if the role is not found.
  @override
  Future<void> updateRole(Role role) async {
    final count = await database.update(
      rolesTableName,
      {
        'display_name': role.displayName,
        'description': role.description,
        'is_active': role.isActive ? 1 : 0,
      },
      where: 'name = ?',
      whereArgs: [role.name],
    );
    if (count == 0) {
      throw RoleDoesNotExistException(role.name);
    }
  }

  /// Retrieves a role by name from SQLite.
  @override
  Future<Role?> getRole(String name) async {
    final results = await database.query(
      rolesTableName,
      where: 'name = ?',
      whereArgs: [name],
    );
    if (results.isEmpty) return null;
    return _mapToRole(results.first);
  }

  /// Lists all roles from SQLite.
  @override
  Future<List<Role>> listRoles({bool includeInactive = false}) async {
    final results = await database.query(
      rolesTableName,
      where: includeInactive ? null : 'is_active = 1',
    );
    return results.map(_mapToRole).toList();
  }

  /// Assigns a role to a user in SQLite.
  @override
  Future<void> assignRole({
    required String userId,
    required String roleName,
    String? scope,
  }) async {
    // Note: SQLite allows multiple NULLs in a UNIQUE/PRIMARY KEY (it treats them as distinct).
    // To treat (user_id, role_name, NULL) as a single unique assignment, we use '' as placeholder.
    await database.insert(assignmentsTableName, {
      'user_id': userId,
      'role_name': roleName,
      'scope': scope ?? '',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Unassigns a role from a user in SQLite.
  @override
  Future<void> unassignRole({
    required String userId,
    required String roleName,
    String? scope,
  }) async {
    await database.delete(
      assignmentsTableName,
      where: 'user_id = ? AND role_name = ? AND scope = ?',
      whereArgs: [userId, roleName, scope ?? ''],
    );
  }

  /// Retrieves all active roles for a user from SQLite.
  @override
  Future<List<Role>> getUserRoles(String userId) async {
    // Joins Roles and Assignments to get active role definitions for a user.
    final results = await database.rawQuery(
      '''
      SELECT DISTINCT r.* FROM $rolesTableName r
      JOIN $assignmentsTableName a ON r.name = a.role_name
      WHERE a.user_id = ? AND r.is_active = 1
    ''',
      [userId],
    );

    return results.map(_mapToRole).toList();
  }

  /// Retrieves all role assignments for a user from SQLite.
  @override
  Future<List<RoleAssignment>> getUserAssignments(String userId) async {
    final results = await database.query(
      assignmentsTableName,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return results.map((row) {
      final scope = row['scope'] as String;
      return RoleAssignment(
        userId: row['user_id'] as String,
        roleName: row['role_name'] as String,
        scope: scope.isEmpty ? null : scope,
      );
    }).toList();
  }

  Role _mapToRole(Map<String, dynamic> row) {
    return Role(
      name: row['name'] as String,
      displayName: row['display_name'] as String,
      description: row['description'] as String,
      isActive: (row['is_active'] as int) == 1,
    );
  }
}
