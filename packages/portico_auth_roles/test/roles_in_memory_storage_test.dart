import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:test/test.dart';

void main() {
  late AuthRolesInMemoryStorage storage;
  late AuthRolesStorageAdapter adapter;

  setUp(() {
    storage = AuthRolesInMemoryStorage();
    adapter = storage;
  });

  group('Roles Management', () {
    final adminRole = Role(
      name: 'admin',
      displayName: 'Admin',
      description: 'Admin role',
    );

    test('createRole and getRole', () async {
      await adapter.createRole(adminRole);
      final role = await adapter.getRole('admin');
      expect(role, equals(adminRole));
    });

    test('clears', () async {
      await adapter.createRole(adminRole);
      final role = await adapter.getRole('admin');
      expect(role, equals(adminRole));

      storage.clear();
      expectLater(storage.getRole('admin'), completion(isNull));
    });

    test('listRoles returns active roles by default', () async {
      final inactiveRole = Role(
        name: 'inactive',
        displayName: 'Inactive',
        description: 'Inactive role',
        isActive: false,
      );
      await adapter.createRole(adminRole);
      await adapter.createRole(inactiveRole);

      final roles = await adapter.listRoles();
      expect(roles, contains(adminRole));
      expect(roles, isNot(contains(inactiveRole)));

      final allRoles = await adapter.listRoles(includeInactive: true);
      expect(allRoles, contains(adminRole));
      expect(allRoles, contains(inactiveRole));
    });

    test('updateRole works', () async {
      await adapter.createRole(adminRole);
      final updatedRole = Role(
        name: 'admin',
        displayName: 'Super Admin',
        description: 'Super Admin role',
        isActive: true,
      );
      await adapter.updateRole(updatedRole);
      final role = await adapter.getRole('admin');
      expect(role?.displayName, equals('Super Admin'));
    });
  });

  group('Role Assignment', () {
    const userId = 'user-123';
    final adminRole = Role(
      name: 'admin',
      displayName: 'Admin',
      description: 'desc',
    );

    test('assignRole and getUserRoles', () async {
      await adapter.createRole(adminRole);
      await adapter.assignRole(userId: userId, roleName: 'admin');

      final roles = await adapter.getUserRoles(userId);
      expect(roles, contains(adminRole));
    });

    test('unassignRole works', () async {
      await adapter.createRole(adminRole);
      await adapter.assignRole(userId: userId, roleName: 'admin');
      await adapter.unassignRole(userId: userId, roleName: 'admin');

      final roles = await adapter.getUserRoles(userId);
      expect(roles, isEmpty);
    });

    test('getUserRoles only returns active roles', () async {
      final inactiveRole = Role(
        name: 'inactive',
        displayName: 'Inactive',
        description: 'desc',
        isActive: false,
      );
      await adapter.createRole(inactiveRole);
      await adapter.assignRole(userId: userId, roleName: 'inactive');

      final roles = await adapter.getUserRoles(userId);
      expect(roles, isEmpty);
    });

    test('getUserAssignments returns assignments', () async {
      await adapter.createRole(adminRole);
      await adapter.assignRole(userId: userId, roleName: 'admin');

      final assignments = await adapter.getUserAssignments(userId);
      expect(assignments, hasLength(1));
      expect(assignments.first.roleName, 'admin');
      expect(assignments.first.userId, userId);
      expect(assignments.first.scope, isNull);
    });

    test('scoped assignments', () async {
      await adapter.createRole(adminRole);
      await adapter.assignRole(
        userId: userId,
        roleName: 'admin',
        scope: 'game_1',
      );
      await adapter.assignRole(
        userId: userId,
        roleName: 'admin',
        scope: 'game_2',
      );

      final assignments = await adapter.getUserAssignments(userId);
      expect(assignments, hasLength(2));
      expect(
        assignments.map((a) => a.scope),
        containsAll(['game_1', 'game_2']),
      );

      // getUserRoles should still return the role definition (unique)
      final roles = await adapter.getUserRoles(userId);
      expect(roles, hasLength(1));
      expect(roles.first.name, 'admin');
    });

    test('unassignRole with scope', () async {
      await adapter.createRole(adminRole);
      await adapter.assignRole(
        userId: userId,
        roleName: 'admin',
        scope: 'game_1',
      );
      await adapter.assignRole(
        userId: userId,
        roleName: 'admin',
        scope: 'game_2',
      );

      await adapter.unassignRole(
        userId: userId,
        roleName: 'admin',
        scope: 'game_1',
      );

      final assignments = await adapter.getUserAssignments(userId);
      expect(assignments, hasLength(1));
      expect(assignments.first.scope, 'game_2');
    });
  });
}
