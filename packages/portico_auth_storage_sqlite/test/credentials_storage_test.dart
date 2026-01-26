import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_storage_sqlite/credentials_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  // Initialize sqflite for ffi
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('AuthCredentialsSqlite', () {
    late Database db;
    late AuthCredentialsSqlite storage;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      storage = AuthCredentialsSqlite(db);
      await storage.initialize();
    });

    tearDown(() async {
      await db.close();
    });

    test('createUser and getPasswordHash', () async {
      final now = DateTime.now();
      await storage.createUser(
        userId: 'test@example.com',
        salt: 'salt123',
        hash: 'hash456',
        creationTime: now,
      );

      final credentials = await storage.getPasswordHash('test@example.com');

      expect(credentials.salt, 'salt123');
      expect(credentials.hash, 'hash456');
    });

    test(
      'getPasswordHash throws UserDoesNotExistException for non-existent user',
      () async {
        expect(
          () => storage.getPasswordHash('nonexistent@example.com'),
          throwsA(isA<UserDoesNotExistException>()),
        );
      },
    );

    test('updatePassword', () async {
      final now = DateTime.now();
      await storage.createUser(
        userId: 'test@example.com',
        salt: 'salt123',
        hash: 'hash456',
        creationTime: now,
      );

      await storage.updatePassword(
        userId: 'test@example.com',
        salt: 'new_salt',
        hash: 'new_hash',
      );

      final credentials = await storage.getPasswordHash('test@example.com');
      expect(credentials.salt, 'new_salt');
      expect(credentials.hash, 'new_hash');
    });

    test('updatePassword throws if user not found', () async {
      expect(
        () => storage.updatePassword(
          userId: 'nonexistent@example.com',
          salt: 'new_salt',
          hash: 'new_hash',
        ),
        throwsA(isA<UserDoesNotExistException>()),
      );
    });

    test('createUser throws if user already exists', () async {
      final now = DateTime.now();
      await storage.createUser(
        userId: 'test@example.com',
        salt: 'salt1',
        hash: 'hash1',
        creationTime: now,
      );

      expect(
        () => storage.createUser(
          userId: 'test@example.com',
          salt: 'salt2',
          hash: 'hash2',
          creationTime: now,
        ),
        throwsA(isA<UserAlreadyExistsException>()),
      );
    });

    test('supports custom table name', () async {
      final customTable = 'MyCredentials';
      final customStorage = AuthCredentialsSqlite(db, tableName: customTable);
      await customStorage.initialize();

      final now = DateTime.now();
      await customStorage.createUser(
        userId: 'custom@example.com',
        salt: 'csalt',
        hash: 'chash',
        creationTime: now,
      );

      final credentials = await customStorage.getPasswordHash(
        'custom@example.com',
      );
      expect(credentials.salt, 'csalt');

      // Verify table exists by querying sqlite_master

      final tableCheck = await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['table', customTable],
      );

      expect(tableCheck, isNotEmpty);
    });

    test('deleteUser successfully removes user', () async {
      await storage.createUser(
        userId: 'test@example.com',
        salt: 'salt',
        hash: 'hash',
        creationTime: DateTime.now(),
      );
      await storage.deleteUser('test@example.com');
      expect(
        () => storage.getPasswordHash('test@example.com'),
        throwsA(isA<UserDoesNotExistException>()),
      );
    });

    test('deleteUser throws if user not found', () async {
      expect(
        () => storage.deleteUser('nonexistent@example.com'),
        throwsA(isA<UserDoesNotExistException>()),
      );
    });
  });
}
