import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:test/test.dart';

void main() {
  group('AuthCredentialsInMemoryStorage', () {
    late AuthCredentialsInMemoryStorage storage;

    setUp(() {
      storage = AuthCredentialsInMemoryStorage();
    });

    test('createUser and getPasswordHash', () async {
      final userId = 'test@example.com';
      final salt = 'salt';
      final hash = 'hash';
      final now = DateTime.now();

      await storage.createUser(
        userId: userId,
        salt: salt,
        hash: hash,
        creationTime: now,
      );

      final result = await storage.getPasswordHash(userId);
      expect(result.salt, equals(salt));
      expect(result.hash, equals(hash));
    });

    test(
      'createUser throws UserAlreadyExistsException if userId exists',
      () async {
        final userId = 'test@example.com';
        final now = DateTime.now();

        await storage.createUser(
          userId: userId,
          salt: 's1',
          hash: 'h1',
          creationTime: now,
        );

        expect(
          () => storage.createUser(
            userId: userId,
            salt: 's2',
            hash: 'h2',
            creationTime: now,
          ),
          throwsA(isA<UserAlreadyExistsException>()),
        );
      },
    );

    test('updatePassword updates correctly', () async {
      final userId = 'test@example.com';
      await storage.createUser(
        userId: userId,
        salt: 's1',
        hash: 'h1',
        creationTime: DateTime.now(),
      );

      await storage.updatePassword(userId: userId, salt: 's2', hash: 'h2');

      final result = await storage.getPasswordHash(userId);
      expect(result.salt, equals('s2'));
      expect(result.hash, equals('h2'));
    });

    test('updatePassword throws for non-existent user', () async {
      expect(
        storage.updatePassword(
          userId: 'none@example.com',
          salt: 's2',
          hash: 'h2',
        ),
        throwsA(isA<UserDoesNotExistException>()),
      );
    });

    test('getPasswordHash throws for non-existent user', () async {
      expect(
        storage.getPasswordHash('none@example.com'),
        throwsA(isA<UserDoesNotExistException>()),
      );
    });
  });
}
