import 'package:portico_auth_storage_sqlite/tokens_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  // Initialize sqflite for ffi
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('AuthStorageSqlite', () {
    late Database db;
    late AuthTokensSqlite storage;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      storage = AuthTokensSqlite(db);
      await storage.initialize();
    });

    tearDown(() async {
      await db.close();
    });

    test('record and get refresh token counter', () async {
      final now = DateTime.now();
      await storage.recordRefreshToken(
        serial: 'serial1',
        userId: 'user1',
        initial: now,
        lastUpdate: now,
        counter: 1,
        name: 'device1',
      );

      final counters = await storage.getRefreshTokenCounter(
        serial: 'serial1',
        userId: 'user1',
      );

      expect(counters, [1]);
    });

    test('update refresh token counter', () async {
      final now = DateTime.now();
      await storage.recordRefreshToken(
        serial: 'serial1',
        userId: 'user1',
        initial: now,
        lastUpdate: now,
        counter: 1,
        name: 'device1',
      );

      final later = now.add(Duration(minutes: 5));
      await storage.updateRefreshTokenCounter(
        serial: 'serial1',
        userId: 'user1',
        lastUpdate: later,
        counter: 2,
      );

      final counters = await storage.getRefreshTokenCounter(
        serial: 'serial1',
        userId: 'user1',
      );

      expect(counters, [2]);
    });

    test('invalidate refresh token', () async {
      final now = DateTime.now();
      await storage.recordRefreshToken(
        serial: 'serial1',
        userId: 'user1',
        initial: now,
        lastUpdate: now,
        counter: 1,
        name: 'device1',
      );

      await storage.invalidateRefreshToken(serial: 'serial1', userId: 'user1');

      final counters = await storage.getRefreshTokenCounter(
        serial: 'serial1',
        userId: 'user1',
      );

      expect(counters, isEmpty);
    });

    test('multiple tokens for different users/serials', () async {
      final now = DateTime.now();
      await storage.recordRefreshToken(
        serial: 's1',
        userId: 'u1',
        initial: now,
        lastUpdate: now,
        counter: 1,
        name: 'd1',
      );
      await storage.recordRefreshToken(
        serial: 's2',
        userId: 'u2',
        initial: now,
        lastUpdate: now,
        counter: 10,
        name: 'd2',
      );

      expect(await storage.getRefreshTokenCounter(serial: 's1', userId: 'u1'), [
        1,
      ]);
      expect(await storage.getRefreshTokenCounter(serial: 's2', userId: 'u2'), [
        10,
      ]);
    });

    test('supports custom table name', () async {
      final customTable = 'CustomTokens';
      final customStorage = AuthTokensSqlite(db, tableName: customTable);
      await customStorage.initialize();

      final now = DateTime.now();
      await customStorage.recordRefreshToken(
        serial: 'cs1',
        userId: 'cu1',
        initial: now,
        lastUpdate: now,
        counter: 5,
        name: 'cd1',
      );

      final counters = await customStorage.getRefreshTokenCounter(
        serial: 'cs1',
        userId: 'cu1',
      );
      expect(counters, [5]);

      // Verify table exists by querying sqlite_master
      final tableCheck = await db.query(
        'sqlite_master',
        where: 'type = ? AND name = ?',
        whereArgs: ['table', customTable],
      );
      expect(tableCheck, isNotEmpty);
    });
  });
}
