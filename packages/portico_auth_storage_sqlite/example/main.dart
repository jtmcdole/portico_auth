import 'package:portico_auth_storage_sqlite/portico_auth_storage_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  print('--- Portico Auth SQLite Storage Example ---');

  // 1. Initialize sqflite for FFI (Desktop/Server)
  sqfliteFfiInit();
  final databaseFactory = databaseFactoryFfi;

  // 2. Open an in-memory database
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  print('In-memory SQLite database opened.');

  // 3. Initialize the storage adapter
  final storage = AuthTokensSqlite(db);
  await storage.initialize();

  // 4. Perform basic operations
  print('\nAdding a refresh token counter...');
  await storage.recordRefreshToken(
    userId: 'user_123',
    serial: 'serial_abc',
    initial: DateTime.now(),
    lastUpdate: DateTime.now(),
    counter: 1,
    name: 'Mobile App',
  );

  print('Retrieving counters...');
  final counters = await storage.getRefreshTokenCounter(
    userId: 'user_123',
    serial: 'serial_abc',
  );

  for (final c in counters) {
    print('Found counter: Value=$c');
  }

  print('\nUpdating counter...');
  await storage.updateRefreshTokenCounter(
    userId: 'user_123',
    serial: 'serial_abc',
    lastUpdate: DateTime.now(),
    counter: 2,
  );

  print('\nInvalidating token...');
  await storage.invalidateRefreshToken(
    serial: 'serial_abc',
    userId: 'user_123',
  );

  final remaining = await storage.getRefreshTokenCounter(
    userId: 'user_123',
    serial: 'serial_abc',
  );
  print('Remaining counters: ${remaining.length}');

  // 5. Cleanup
  await db.close();
  print('\nDatabase closed.');
}
