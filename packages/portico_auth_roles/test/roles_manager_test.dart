import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:test/test.dart';

void main() {
  late AuthRolesInMemoryStorage storage;
  late AuthRoleManager manager;

  setUp(() {
    storage = AuthRolesInMemoryStorage();
    manager = AuthRoleManager(storage);
  });

  group('Role Management', () {
    test('createRole creates a role', () async {
      await manager.createRole(
        name: 'admin',
        displayName: 'Admin',
        description: 'Admin role',
      );
      final role = await manager.getRole('admin');
      expect(role?.name, equals('admin'));
      expect(role?.displayName, equals('Admin'));
    });

    test('createRole throws if role already exists', () async {
      await manager.createRole(
        name: 'admin',
        displayName: 'Admin',
        description: 'desc',
      );
      expect(
        () => manager.createRole(
          name: 'admin',
          displayName: 'Admin',
          description: 'desc',
        ),
        throwsA(
          isA<RoleAlreadyExistsException>().having(
            (x) => x.message,
            'message',
            contains('Role already exists: admin'),
          ),
        ),
      );
    });

    test('updateRoleMetadata updates display name and description', () async {
      await manager.createRole(
        name: 'admin',
        displayName: 'Admin',
        description: 'desc',
      );
      await manager.updateRoleMetadata(
        name: 'admin',
        displayName: 'Super Admin',
        description: 'New desc',
      );
      final role = await manager.getRole('admin');
      expect(role?.displayName, equals('Super Admin'));
      expect(role?.description, equals('New desc'));
    });

    test('deactivateRole marks role as inactive', () async {
      await manager.createRole(
        name: 'admin',
        displayName: 'Admin',
        description: 'desc',
      );
      await manager.deactivateRole('admin');
      final role = await manager.getRole('admin');
      expect(role?.isActive, isFalse);
    });

    group('listRoles', () {
      late Role role1, role3;
      setUp(() async {
        role1 = await manager.createRole(
          name: 'fuzz',
          displayName: 'Fuzz',
          description: 'desc2',
        );
        await manager.createRole(
          name: 'admin',
          displayName: 'Admin',
          description: 'desc',
        );
        role3 = await manager.deactivateRole('admin');
      });

      test('will return all roles', () async {
        expect(
          manager.listRoles(includeInactive: true),
          completion([role1, role3]),
        );
      });

      test('will return only active', () async {
        expect(manager.listRoles(), completion([role1]));
      });
    });

    test('activateRole marks role as active', () async {
      await manager.createRole(
        name: 'admin',
        displayName: 'Admin',
        description: 'desc',
        isActive: false,
      );
      await manager.activateRole('admin');
      final role = await manager.getRole('admin');
      expect(role?.isActive, isTrue);
    });
  });

  group('User Role Assignments', () {
    const userId = 'user-1';

    test('assignRoleToUser and getUserRoles', () async {
      await manager.createRole(
        name: 'admin',
        displayName: 'Admin',
        description: 'desc',
      );
      await manager.assignRoleToUser(userId: userId, roleName: 'admin');

      final roles = await manager.getUserRoles(userId);
      expect(roles.map((r) => r.name), contains('admin'));
    });

    test('assignRoleToUser fails for unknown roles', () async {
      expectLater(
        () => manager.assignRoleToUser(userId: userId, roleName: 'fuzz'),
        throwsA(
          isA<RoleDoesNotExistException>().having(
            (x) => x.toString(),
            'toString',
            contains('Role does not exist: fuzz'),
          ),
        ),
      );
    });

    test('unassignRoleFromUser removes assignment', () async {
      await manager.createRole(
        name: 'admin',
        displayName: 'Admin',
        description: 'desc',
      );
      await manager.assignRoleToUser(userId: userId, roleName: 'admin');
      await manager.unassignRoleFromUser(userId: userId, roleName: 'admin');

      final roles = await manager.getUserRoles(userId);
      expect(roles, isEmpty);
    });

    test('getUserRoles only returns active roles', () async {
      await manager.createRole(
        name: 'admin',
        displayName: 'Admin',
        description: 'desc',
      );
      await manager.assignRoleToUser(userId: userId, roleName: 'admin');
      await manager.deactivateRole('admin');

      final roles = await manager.getUserRoles(userId);
      expect(roles, isEmpty);
    });
  });

  group('Scoped Assignments', () {
    const userId = 'user-scoped';

    test('can assign role with scope', () async {
      await manager.createRole(
        name: 'moderator',
        displayName: 'Mod',
        description: 'desc',
      );

      await manager.assignRoleToUser(
        userId: userId,
        roleName: 'moderator',
        scope: 'forum_1',
      );
      await manager.assignRoleToUser(
        userId: userId,
        roleName: 'moderator',
        scope: 'forum_2',
      );

      final assignments = await manager.getUserAssignments(userId);
      expect(assignments, hasLength(2));
      expect(
        assignments.map((a) => a.scope),
        containsAll(['forum_1', 'forum_2']),
      );
    });

    test('getUserRoles deduplicates roles across scopes', () async {
      await manager.createRole(
        name: 'moderator',
        displayName: 'Mod',
        description: 'desc',
      );

      await manager.assignRoleToUser(
        userId: userId,
        roleName: 'moderator',
        scope: 'forum_1',
      );
      await manager.assignRoleToUser(
        userId: userId,
        roleName: 'moderator',
        scope: 'forum_2',
      );

      final roles = await manager.getUserRoles(userId);
      expect(roles, hasLength(1));
      expect(roles.first.name, 'moderator');
    });

    test('unassignRoleFromUser respects scope', () async {
      await manager.createRole(
        name: 'moderator',
        displayName: 'Mod',
        description: 'desc',
      );

      await manager.assignRoleToUser(
        userId: userId,
        roleName: 'moderator',
        scope: 'forum_1',
      );
      await manager.assignRoleToUser(
        userId: userId,
        roleName: 'moderator',
        scope: 'forum_2',
      );

      await manager.unassignRoleFromUser(
        userId: userId,
        roleName: 'moderator',
        scope: 'forum_1',
      );

      final assignments = await manager.getUserAssignments(userId);
      expect(assignments, hasLength(1));
      expect(assignments.first.scope, 'forum_2');
    });
  });
}
