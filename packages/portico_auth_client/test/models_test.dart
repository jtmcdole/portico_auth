import 'package:portico_auth_client/src/models.dart';
import 'package:test/test.dart';

void main() {
  group('UserRole', () {
    test('supports value equality', () {
      const role1 = UserRole(role: 'admin', scope: 'org:123');
      const role2 = UserRole(role: 'admin', scope: 'org:123');
      const role3 = UserRole(role: 'editor');

      expect(role1, equals(role2));
      expect(role1, isNot(equals(role3)));
    });

    test('toString includes scope when present', () {
      expect(
        const UserRole(role: 'admin', scope: 'org:123').toString(),
        equals('admin:org:123'),
      );
      expect(const UserRole(role: 'editor').toString(), equals('editor'));
    });
  });

  group('AuthUser', () {
    test('supports value equality', () {
      final user1 = AuthUser(
        id: 'user1',
        name: 'User One',
        roles: const [UserRole(role: 'admin')],
      );
      final user2 = AuthUser(
        id: 'user1',
        name: 'User One',
        roles: const [UserRole(role: 'admin')],
      );
      final user3 = AuthUser(id: 'user2', name: 'User Two', roles: const []);

      expect(user1, equals(user2));
      expect(user1, isNot(equals(user3)));
    });
  });

  group('AuthState', () {
    test('Authenticated state supports equality', () {
      final user = AuthUser(id: '1', roles: const []);
      final state1 = Authenticated(user);
      final state2 = Authenticated(user);

      expect(state1, equals(state2));
    });

    test('Unauthenticated state supports equality', () {
      expect(const Unauthenticated(), equals(const Unauthenticated()));
    });

    test('Authenticating state supports equality', () {
      expect(const Authenticating(), equals(const Authenticating()));
    });
  });
}
