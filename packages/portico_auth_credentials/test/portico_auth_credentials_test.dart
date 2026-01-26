import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:test/test.dart';

class FakeHashAdapter implements HashAdapter {
  final _random = Random();

  @override
  Future<List<int>> hash(String password, List<int> salt) async {
    // Fast hash for testing using sha256
    final bytes = utf8.encode('$password${base64.encode(salt)}');
    return sha256.convert(bytes).bytes;
  }

  @override
  Future<List<int>> salt() async {
    return List.generate(16, (_) => _random.nextInt(256));
  }
}

void main() {
  group('AuthCredentialsManager', () {
    late AuthCredentialsInMemoryStorage inMemoryStorage;
    late AuthCredentialsManager service;

    setUp(() {
      inMemoryStorage = AuthCredentialsInMemoryStorage();
      service = AuthCredentialsManager(
        storage: inMemoryStorage,
        hasher: FakeHashAdapter(),
      );
    });

    group('registerUser', () {
      test('successfully registers a new user', () async {
        final userId = 'user@example.com';
        final password = 'password123';

        await service.registerUser(userId, password);

        final credentials = await inMemoryStorage.getPasswordHash(userId);
        expect(credentials.hash, isNotEmpty);
        expect(credentials.salt, isNotEmpty);
      });

      test('throws UserAlreadyExistsException if userId is taken', () async {
        final userId = 'user@example.com';
        await service.registerUser(userId, 'pass1234');

        expect(
          () => service.registerUser(userId, 'pass1234'),
          throwsA(isA<UserAlreadyExistsException>()),
        );
      });

      test('throws InvalidCredentialsException if userId is bad', () async {
        final userId = '1';
        expect(
          () => service.registerUser(userId, 'pass1234'),
          throwsA(isA<InvalidCredentialsException>()),
        );
      });

      test('throws InvalidCredentialsException if password is short', () async {
        final userId = 'user@example.com';
        expect(
          () => service.registerUser(userId, 'pass123'),
          throwsA(isA<InvalidCredentialsException>()),
        );
      });
    });

    group('verifyCredentials', () {
      test('returns true for correct password', () async {
        final userId = 'user@example.com';
        final password = 'password123';
        await service.registerUser(userId, password);

        final result = await service.verifyCredentials(userId, password);
        expect(result, isTrue);
      });

      test(
        'throws InvalidCredentialsException for incorrect password',
        () async {
          final userId = 'user@example.com';
          final password = 'password123';
          await service.registerUser(userId, password);

          expect(
            () => service.verifyCredentials(userId, 'wrongpassword'),
            throwsA(isA<InvalidCredentialsException>()),
          );
        },
      );

      test('throws UserDoesNotExistException for non-existent user', () async {
        expect(
          () => service.verifyCredentials('none@example.com', 'pass'),
          throwsA(isA<UserDoesNotExistException>()),
        );
      });
    });

    group('updatePassword', () {
      test('successfully updates password for valid credentials', () async {
        final userId = 'user@example.com';
        final oldPassword = 'oldPassword123';
        final newPassword = 'newPassword456';

        await service.registerUser(userId, oldPassword);

        final oldCredentials = await inMemoryStorage.getPasswordHash(userId);

        await service.updatePassword(userId, oldPassword, newPassword);

        final newCredentials = await inMemoryStorage.getPasswordHash(userId);
        expect(newCredentials.hash, isNot(equals(oldCredentials.hash)));
        expect(newCredentials.salt, isNot(equals(oldCredentials.salt)));

        expect(await service.verifyCredentials(userId, newPassword), isTrue);
        expect(
          () => service.verifyCredentials(userId, oldPassword),
          throwsA(isA<InvalidCredentialsException>()),
        );
      });

      test('throws exception for invalid old password', () async {
        final userId = 'user@example.com';
        final oldPassword = 'oldPassword123';
        await service.registerUser(userId, oldPassword);

        expect(
          () =>
              service.updatePassword(userId, 'wrongOldPassword', 'newPassword'),
          throwsA(isA<InvalidCredentialsException>()),
        );
      });

      test('throws exception for non-existent user', () async {
        expect(
          () => service.updatePassword('none@example.com', 'old', 'new'),
          throwsA(isA<UserDoesNotExistException>()),
        );
      });

      test('re-hashes with new salt even if password is the same', () async {
        final userId = 'user@example.com';
        final password = 'samePassword123';

        await service.registerUser(userId, password);
        final firstCredentials = await inMemoryStorage.getPasswordHash(userId);

        await service.updatePassword(userId, password, password);
        final secondCredentials = await inMemoryStorage.getPasswordHash(userId);

        expect(secondCredentials.salt, isNot(equals(firstCredentials.salt)));
        expect(secondCredentials.hash, isNot(equals(firstCredentials.hash)));
        expect(await service.verifyCredentials(userId, password), isTrue);
      });

      test('deleteUser successfully removes user', () async {
        final userId = 'user@example.com';
        await service.registerUser(userId, 'password');
        await service.deleteUser(userId);

        expect(
          () => service.verifyCredentials(userId, 'password'),
          throwsA(isA<UserDoesNotExistException>()),
        );
      });

      test(
        'deleteUser throws UserDoesNotExistException for non-existent user',
        () async {
          expect(
            () => service.deleteUser('nonexistent@example.com'),
            throwsA(isA<UserDoesNotExistException>()),
          );
        },
      );
    });
  });

  group('password verification', () {
    test('length >=8', () {
      expect(
        () => AuthValidation.validatePasswordLength('1' * 7),
        throwsA(
          isA<InvalidCredentialsException>().having(
            (x) => x.message,
            'message',
            contains('Password too short'),
          ),
        ),
      );
      expect(AuthValidation.validatePasswordLength('1' * 8), isTrue);
    });

    test('letter, Letter, digit, special', () {
      final rigid = AuthValidation.rigid();

      // Other than being a meme - this should be "secure", but this check
      // is just rigid validation, not secure.
      for (var password in [
        'Correct Horse Battery Staple',
        r"AaBb0+'",
        r"AaBb__+'",
        r"_a_b__+'",
        r"A_B_1_+'",
      ]) {
        expect(
          () => rigid.password(password),
          throwsA(
            isA<InvalidCredentialsException>().having(
              (x) => x.message,
              'message',
              contains("Password not complex enough"),
            ),
          ),
        );
      }

      expect(rigid.password(r"AaBb0+$'"), isTrue);
    });
  });
}
