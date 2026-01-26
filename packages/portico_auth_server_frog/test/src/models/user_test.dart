import 'package:portico_auth_server_frog/portico_auth_server_frog.dart';
import 'package:test/test.dart';

void main() {
  group('User', () {
    const id = 'user-123';
    const roles = [
      UserRole(role: 'admin', scope: 'global'),
      UserRole(role: 'editor'),
    ];
    const rolesJson = [
      {'role': 'admin', 'scope': 'global'},
      {'role': 'editor', 'scope': ''},
    ];
    const metadata = {'iat': 1234567890, 'exp': 1234567899};

    test('can be instantiated', () {
      final user = User(id: id, roles: roles, metadata: metadata);

      expect(user.id, equals(id));
      expect(user.roles, equals(roles));
      expect(user.metadata, equals(metadata));
    });

    test('supports value equality', () {
      final user1 = User(id: id, roles: roles, metadata: metadata);

      final user2 = User(id: id, roles: roles, metadata: metadata);

      expect(user1, equals(user2));
    });

    test('fromJson creates a valid instance', () {
      final json = {'id': id, 'roles': rolesJson, 'metadata': metadata};

      final user = User.fromJson(json);

      expect(user.id, equals(id));
      expect(user.roles, equals(roles));
      expect(user.metadata, equals(metadata));
    });

    test('toJson returns a valid map', () {
      final user = User(id: id, roles: roles, metadata: metadata);

      final json = user.toJson();

      expect(json['id'], equals(id));
      expect(json['roles'], equals(rolesJson));
      expect(json['metadata'], equals(metadata));
    });
  });
}
