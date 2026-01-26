import 'role.dart';
import 'role_assignment.dart';
import 'role_exceptions.dart';
import 'roles_storage_adapter.dart';

/// Business logic for managing roles and assignments.
class AuthRoleManager {
  final AuthRolesStorageAdapter storage;

  AuthRoleManager(this.storage);

  /// Creates a new role.
  Future<Role> createRole({
    required String name,
    required String displayName,
    required String description,
    bool isActive = true,
  }) async {
    final role = Role(
      name: name,
      displayName: displayName,
      description: description,
      isActive: isActive,
    );
    await storage.createRole(role);
    return role;
  }

  /// Updates role metadata.
  Future<Role> updateRoleMetadata({
    required String name,
    required String displayName,
    required String description,
  }) async {
    final existing = await storage.getRole(name);
    if (existing == null) {
      throw RoleDoesNotExistException(name);
    }
    final updated = Role(
      name: name,
      displayName: displayName,
      description: description,
      isActive: existing.isActive,
    );
    await storage.updateRole(updated);
    return updated;
  }

  /// Deactivates a role (soft delete).
  Future<Role> deactivateRole(String name) async {
    final existing = await storage.getRole(name);
    if (existing == null) {
      throw RoleDoesNotExistException(name);
    }
    final updated = Role(
      name: name,
      displayName: existing.displayName,
      description: existing.description,
      isActive: false,
    );
    await storage.updateRole(updated);
    return updated;
  }

  /// Activates a role.
  Future<Role> activateRole(String name) async {
    final existing = await storage.getRole(name);
    if (existing == null) {
      throw RoleDoesNotExistException(name);
    }
    final updated = Role(
      name: name,
      displayName: existing.displayName,
      description: existing.description,
      isActive: true,
    );
    await storage.updateRole(updated);
    return updated;
  }

  /// Retrieves a role by name.
  Future<Role?> getRole(String name) async {
    return storage.getRole(name);
  }

  /// Lists all roles.
  Future<List<Role>> listRoles({bool includeInactive = false}) async {
    return storage.listRoles(includeInactive: includeInactive);
  }

  /// Assigns a role to a user, optionally scoped to a resource.
  Future<void> assignRoleToUser({
    required String userId,
    required String roleName,
    String? scope,
  }) async {
    final role = await storage.getRole(roleName);
    if (role == null) {
      throw RoleDoesNotExistException(roleName);
    }
    await storage.assignRole(userId: userId, roleName: roleName, scope: scope);
  }

  /// Unassigns a role from a user.
  Future<void> unassignRoleFromUser({
    required String userId,
    required String roleName,
    String? scope,
  }) async {
    await storage.unassignRole(
      userId: userId,
      roleName: roleName,
      scope: scope,
    );
  }

  /// Retrieves all active roles for a user.
  /// Returns the role definitions, not the assignments.
  Future<List<Role>> getUserRoles(String userId) async {
    return storage.getUserRoles(userId);
  }

  /// Retrieves all role assignments for a user.
  Future<List<RoleAssignment>> getUserAssignments(String userId) async {
    return storage.getUserAssignments(userId);
  }
}
