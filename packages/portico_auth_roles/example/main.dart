import 'package:portico_auth_roles/portico_auth_roles.dart';

void main() async {
  print('--- RBAC Core Verification ---');

  final storage = AuthRolesInMemoryStorage();
  final manager = AuthRoleManager(storage);

  // 1. Create roles
  print('Creating roles...');
  await manager.createRole(
    name: 'admin',
    displayName: 'Administrator',
    description: 'Full system access',
  );
  await manager.createRole(
    name: 'editor',
    displayName: 'Editor',
    description: 'Can edit content',
  );

  // 2. List roles
  final roles = await manager.listRoles();
  print('Active roles: ${[...roles.map((r) => r.name)]}'); // [admin, editor]

  // 3. Assign roles to a user
  const userId = 'user_001';
  print('Assigning roles to $userId...');
  await manager.assignRoleToUser(userId: userId, roleName: 'admin');
  await manager.assignRoleToUser(userId: userId, roleName: 'editor');

  // 4. Verify assignments
  final userRoles = await manager.getUserRoles(userId);
  print('User roles: ${[userRoles.map((r) => r.name)]}'); // [(admin, editor)]

  // 5. Deactivate a role and verify it is hidden
  print('Deactivating admin role...');
  await manager.deactivateRole('admin');

  final updatedUserRoles = await manager.getUserRoles(userId);
  print(
    'User roles after deactivation: ${[...updatedUserRoles.map((r) => r.name)]}',
  ); // [editor]

  print('--- Verification Complete ---');
}
