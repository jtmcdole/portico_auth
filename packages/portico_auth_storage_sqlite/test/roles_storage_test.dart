import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_storage_sqlite/roles_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  // Initialize sqflite for ffi
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('AuthRolesSqlite', () {
    late Database db;
    late AuthRolesSqlite storage;
    late AuthRolesStorageAdapter adapter;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      storage = AuthRolesSqlite(db);
      await storage.initialize();
      adapter = storage;
    });

    tearDown(() async {
      await db.close();
    });

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

    test('createRole throws if exists', () async {
      await adapter.createRole(adminRole);
      expect(
        () => adapter.createRole(adminRole),
        throwsA(isA<RoleAlreadyExistsException>()),
      );
    });

    test('updateRole works', () async {
      await adapter.createRole(adminRole);
      final updated = Role(
        name: 'admin',
        displayName: 'Super Admin',
        description: 'Updated desc',
        isActive: true,
      );
      await adapter.updateRole(updated);
      final role = await adapter.getRole('admin');
      expect(role?.displayName, 'Super Admin');
      expect(role?.description, 'Updated desc');
    });

    test('listRoles filters by isActive', () async {
      final inactive = Role(
        name: 'inactive',
        displayName: 'Inactive',
        description: 'desc',
        isActive: false,
      );
      await adapter.createRole(adminRole);
      await adapter.createRole(inactive);

      final activeRoles = await adapter.listRoles();
      expect(activeRoles, contains(adminRole));
      expect(activeRoles, isNot(contains(inactive)));

      final allRoles = await adapter.listRoles(includeInactive: true);
      expect(allRoles, hasLength(2));
    });

    group('Assignments', () {
      const userId = 'user-1';

      test('assignRole and getUserRoles', () async {
        await adapter.createRole(adminRole);
        await adapter.assignRole(userId: userId, roleName: 'admin');

        final roles = await adapter.getUserRoles(userId);
        expect(roles, contains(adminRole));
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

        // Unassign one scope
        await adapter.unassignRole(
          userId: userId,
          roleName: 'admin',
          scope: 'game_1',
        );
        final remaining = await adapter.getUserAssignments(userId);
        expect(remaining, hasLength(1));
        expect(remaining.first.scope, 'game_2');
      });

      test('getUserRoles only returns unique active roles', () async {
        await adapter.createRole(adminRole);
        await adapter.assignRole(
          userId: userId,
          roleName: 'admin',
          scope: 's1',
        );
        await adapter.assignRole(
          userId: userId,
          roleName: 'admin',
          scope: 's2',
        );

        final roles = await adapter.getUserRoles(userId);
        expect(roles, hasLength(1));
        expect(roles.first.name, 'admin');

        // Deactivate role
        await adapter.updateRole(
          Role(
            name: 'admin',
            displayName: 'Admin',
            description: 'desc',
            isActive: false,
          ),
        );

        final rolesAfter = await adapter.getUserRoles(userId);
        expect(rolesAfter, isEmpty);
      });

      test('unassignRole with null scope', () async {
        await adapter.createRole(adminRole);
        await adapter.assignRole(
          userId: userId,
          roleName: 'admin',
        ); // null scope

        var assignments = await adapter.getUserAssignments(userId);
        expect(assignments, hasLength(1));
        expect(assignments.first.scope, isNull);

        await adapter.unassignRole(
          userId: userId,
          roleName: 'admin',
        ); // should match null scope
        assignments = await adapter.getUserAssignments(userId);
        expect(assignments, isEmpty);
      });
    });
  });
}
