import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_storage_yaml/src/roles_yaml.dart';
import 'package:test/test.dart';

void main() {
  test('Parses yaml', () async {
    final auth = AuthRolesYaml(
      yaml: '''
kind: roles
roles:
  - name: admin
    display_name: Administrator
    description: System administrator
    is_active: true
  - name: user
    display_name: Regular User
    description: Standard user access
    is_active: true
assignments:
  - user_id: user1@example.com
    role_name: admin
  - user_id: user2@example.com
    role_name: user
    scope: tenant1
''',
    );

    final admin = await auth.getRole('admin');
    expect(admin, isNotNull);
    expect(admin!.displayName, 'Administrator');

    final userRoles = await auth.getUserRoles('user1@example.com');
    expect(userRoles, hasLength(1));
    expect(userRoles.first.name, 'admin');

    final user2Assignments = await auth.getUserAssignments('user2@example.com');
    expect(user2Assignments, hasLength(1));
    expect(user2Assignments.first.roleName, 'user');
    expect(user2Assignments.first.scope, 'tenant1');
  });

  test('Updates roles and persists to yaml', () async {
    final auth = AuthRolesYaml();
    final updates = <String>[];
    auth.onYamlUpdate = (String yaml) => updates.add(yaml);

    await auth.createRole(
      const Role(
        name: 'editor',
        displayName: 'Editor',
        description: 'Can edit content',
      ),
    );

    expect(updates, hasLength(1));
    expect(updates.first, contains('kind: roles'));
    expect(updates.first, contains('name: editor'));

    final auth2 = AuthRolesYaml(yaml: updates.first);
    final editor = await auth2.getRole('editor');
    expect(editor, isNotNull);
    expect(editor!.displayName, 'Editor');
  });

  test('Assigns and unassigns roles', () async {
    final auth = AuthRolesYaml(
      yaml: '''
kind: roles
roles:
  - name: admin
    display_name: Administrator
    description: System administrator
''',
    );

    final updates = <String>[];
    auth.onYamlUpdate = (String yaml) => updates.add(yaml);

    await auth.assignRole(userId: 'user1@example.com', roleName: 'admin');
    expect(updates, hasLength(1));
    expect(updates.last, contains('user_id: user1@example.com'));

    final auth2 = AuthRolesYaml(yaml: updates.last);
    expect(await auth2.getUserAssignments('user1@example.com'), hasLength(1));

    await auth.unassignRole(userId: 'user1@example.com', roleName: 'admin');
    expect(updates, hasLength(2));
    expect(updates.last, isNot(contains('user1@example.com')));

    final auth3 = AuthRolesYaml(yaml: updates.last);
    expect(await auth3.getUserAssignments('user1@example.com'), isEmpty);
  });

  test('Exceptions for existing/missing roles', () async {
    final auth = AuthRolesYaml(
      yaml: '''
kind: roles
roles:
  - name: admin
    display_name: Administrator
    description: System administrator
''',
    );

    expect(
      () => auth.createRole(
        const Role(name: 'admin', displayName: 'Admin', description: 'Desc'),
      ),
      throwsA(isA<RoleAlreadyExistsException>()),
    );

    expect(
      () => auth.updateRole(
        const Role(name: 'editor', displayName: 'Editor', description: 'Desc'),
      ),
      throwsA(isA<RoleDoesNotExistException>()),
    );
  });

  test(
    'getUserRoles returns unique active roles for multiple assignments',
    () async {
      final auth = AuthRolesYaml(
        yaml: '''
kind: roles
roles:
  - name: admin
    display_name: Admin
    is_active: true
  - name: user
    display_name: User
    is_active: true
  - name: inactive
    display_name: Inactive
    is_active: false
assignments:
  - user_id: u1
    role_name: admin
  - user_id: u1
    role_name: user
  - user_id: u1
    role_name: inactive
  - user_id: u1
    role_name: admin
    scope: s1
''',
      );

      final roles = await auth.getUserRoles('u1');
      expect(roles, hasLength(2));
      expect(roles.map((r) => r.name), containsAll(['admin', 'user']));
    },
  );

  test('listRoles filters correctly', () async {
    final auth = AuthRolesYaml(
      yaml: '''
kind: roles
roles:
  - name: r1
    display_name: r1
    is_active: true
  - name: r2
    display_name: r2
    is_active: false
''',
    );

    expect(await auth.listRoles(includeInactive: true), hasLength(2));
    expect(await auth.listRoles(includeInactive: false), hasLength(1));
  });

  test('updateRole successful', () async {
    final auth = AuthRolesYaml(
      yaml: '''
kind: roles
roles:
  - name: r1
    display_name: r1
''',
    );
    await auth.updateRole(
      const Role(name: 'r1', displayName: 'r1 updated', description: ''),
    );
    final r = await auth.getRole('r1');
    expect(r!.displayName, 'r1 updated');
  });

  test('Handles empty roles and assignments', () {
    final roles = AuthRolesYaml(
      yaml: 'kind: roles\nroles: []\nassignments: []',
    );
    expect(roles.roles, isEmpty);
    expect(roles.assignments, isEmpty);
  });

  test('Prevents YAML injection via role name and user ID', () async {
    final auth = AuthRolesYaml();
    String? capturedYaml;
    auth.onYamlUpdate = (yaml) => capturedYaml = yaml;

    const maliciousRoleName =
        'admin\n  - name: injected_role\n    display_name: Injected\n    description: Injected\n    is_active: true';
    const maliciousUserId = 'user@example.com\n    role_name: injected_role';

    await auth.createRole(
      const Role(
        name: maliciousRoleName,
        displayName: 'Normal',
        description: 'Normal',
      ),
    );

    await auth.assignRole(userId: maliciousUserId, roleName: maliciousRoleName);

    print('capturedYaml: $capturedYaml');
    expect(capturedYaml, isNotNull);
    // Malicious strings should be quoted and escaped
    expect(
      capturedYaml,
      contains('"${maliciousRoleName.replaceAll('\n', '\\n')}"'),
    );
    expect(
      capturedYaml,
      contains('"${maliciousUserId.replaceAll('\n', '\\n')}"'),
    );

    final auth2 = AuthRolesYaml(yaml: capturedYaml!);
    final role = await auth2.getRole(maliciousRoleName);
    expect(role, isNotNull);

    // Verify injected role DOES NOT exist
    expect(await auth2.getRole('injected_role'), isNull);

    // Verify injected assignment DOES NOT exist
    final assignments = await auth2.getUserAssignments('user@example.com');
    expect(assignments, isEmpty);
  });
}
