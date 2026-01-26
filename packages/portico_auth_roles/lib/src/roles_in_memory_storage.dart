import 'role.dart';
import 'role_assignment.dart';
import 'role_exceptions.dart';
import 'roles_storage_adapter.dart';

/// In-memory implementation of [AuthRolesStorageAdapter].
final class AuthRolesInMemoryStorage implements AuthRolesStorageAdapter {
  final Map<String, Role> _roles = {};
  final Set<RoleAssignment> _assignments = {};

  /// Returns an unmodifiable map of roles in memory.
  Map<String, Role> get roles => Map.unmodifiable(_roles);

  /// Returns an unmodifiable set of role assignments in memory.
  Set<RoleAssignment> get assignments => Set.unmodifiable(_assignments);

  /// Clears all roles and assignments from memory.
  void clear() {
    _roles.clear();
    _assignments.clear();
  }

  /// Creates a new role in memory.
  ///
  /// Throws [RoleAlreadyExistsException] if a role with the same name exists.
  @override
  Future<void> createRole(Role role) async {
    if (_roles.containsKey(role.name)) {
      throw RoleAlreadyExistsException(role.name);
    }
    _roles[role.name] = role;
  }

  /// Updates an existing role in memory.
  ///
  /// Throws [RoleDoesNotExistException] if the role is not found.
  @override
  Future<void> updateRole(Role role) async {
    if (!_roles.containsKey(role.name)) {
      throw RoleDoesNotExistException(role.name);
    }
    _roles[role.name] = role;
  }

  /// Retrieves a role by name from memory.
  @override
  Future<Role?> getRole(String name) async {
    return _roles[name];
  }

  /// Lists all roles from memory.
  @override
  Future<List<Role>> listRoles({bool includeInactive = false}) async {
    if (includeInactive) {
      return [..._roles.values];
    }
    return [..._roles.values.where((r) => r.isActive)];
  }

  /// Assigns a role to a user in memory.
  @override
  Future<void> assignRole({
    required String userId,
    required String roleName,
    String? scope,
  }) async {
    _assignments.add(
      RoleAssignment(userId: userId, roleName: roleName, scope: scope),
    );
  }

  /// Unassigns a role from a user in memory.
  @override
  Future<void> unassignRole({
    required String userId,
    required String roleName,
    String? scope,
  }) async {
    _assignments.remove(
      RoleAssignment(userId: userId, roleName: roleName, scope: scope),
    );
  }

  /// Retrieves all active roles for a user from memory.
  @override
  Future<List<Role>> getUserRoles(String userId) async {
    final roleNames = {
      ..._assignments.where((a) => a.userId == userId).map((a) => a.roleName),
    };

    return [
      ..._roles.values.where((r) => r.isActive && roleNames.contains(r.name)),
    ];
  }

  /// Retrieves all role assignments for a user from memory.
  @override
  Future<List<RoleAssignment>> getUserAssignments(String userId) async {
    return [..._assignments.where((a) => a.userId == userId)];
  }
}
