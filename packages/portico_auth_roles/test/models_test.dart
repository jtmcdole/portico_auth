import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:test/test.dart';

void main() {
  group('Role', () {
    test('supports value equality', () {
      final role1 = Role(
        name: 'admin',
        displayName: 'Administrator',
        description: 'Admin role',
        isActive: true,
      );
      final role2 = Role(
        name: 'admin',
        displayName: 'Administrator',
        description: 'Admin role',
        isActive: true,
      );
      expect(role1, equals(role2));
    });

    test('toJson and fromJson work correctly', () {
      final role = Role(
        name: 'admin',
        displayName: 'Administrator',
        description: 'Admin role',
        isActive: true,
      );
      final json = role.toJson();
      expect(json, {
        'name': 'admin',
        'display_name': 'Administrator',
        'description': 'Admin role',
        'is_active': true,
      });
      expect(Role.fromJson(json), equals(role));
    });
  });

  group('RoleAssignment', () {
    test('supports value equality', () {
      final assignment1 = RoleAssignment(userId: 'user1', roleName: 'admin');
      final assignment2 = RoleAssignment(userId: 'user1', roleName: 'admin');
      expect(assignment1, equals(assignment2));
    });

    test('toJson and fromJson work correctly', () {
      final assignment = RoleAssignment(userId: 'user1', roleName: 'admin');
      final json = assignment.toJson();
      expect(json, {'user_id': 'user1', 'role_name': 'admin'});
      expect(RoleAssignment.fromJson(json), equals(assignment));
    });
  });
}
