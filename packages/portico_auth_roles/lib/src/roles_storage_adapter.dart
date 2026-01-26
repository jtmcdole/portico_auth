import 'role.dart';
import 'role_assignment.dart';

/// Interface for auth roles storage.
abstract interface class AuthRolesStorageAdapter {
  /// Creates a new role.
  Future<void> createRole(Role role);

  /// Updates an existing role (e.g., description, displayName, isActive).
  Future<void> updateRole(Role role);

  /// Retrieves a role by its unique [name].
  Future<Role?> getRole(String name);

  /// Lists all roles. If [includeInactive] is false, only active roles are returned.
  Future<List<Role>> listRoles({bool includeInactive});

  /// Assigns a role to a user, optionally scoped to a specific resource.
  Future<void> assignRole({
    required String userId,
    required String roleName,
    String? scope,
  });

  /// Unassigns a role from a user.
  Future<void> unassignRole({
    required String userId,
    required String roleName,
    String? scope,
  });

  /// Retrieves all active roles assigned to a user.
  /// Note: This returns the unique roles definitions.
  Future<List<Role>> getUserRoles(String userId);

  /// Retrieves all role assignments for a user.
  Future<List<RoleAssignment>> getUserAssignments(String userId);
}
