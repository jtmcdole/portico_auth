import 'tokens_storage_adapter.dart';

/// Implements in-memory storage for token metadata.
final class AuthTokensInMemoryStorage implements AuthTokensStorageAdapter {
  /// The in-memory storage for refresh token records.
  final memory = <String, MemoryRecord>{};

  /// Clears all token records from memory.
  void clear() => memory.clear();

  @override
  Future<void> invalidateRefreshToken({
    required String serial,
    required String userId,
  }) async {
    memory.remove('$serial+$userId');
  }

  @override
  Future<List<String>> invalidateAllRefreshTokens({
    required String userId,
  }) async {
    final serials = <String>[];
    memory.removeWhere((key, record) {
      if (record.userId == userId) {
        serials.add(record.serial);
        return true;
      }
      return false;
    });
    return serials;
  }

  @override
  Future<void> recordRefreshToken({
    required String serial,
    required String userId,
    required DateTime initial,
    required DateTime lastUpdate,
    required num counter,
    required String name,
  }) async {
    memory['$serial+$userId'] = (
      serial: serial,
      userId: userId,
      initial: initial,
      lastUpdate: lastUpdate,
      counter: counter,
      name: name,
    );
  }

  @override
  Future<List<num>> getRefreshTokenCounter({
    required String serial,
    required String userId,
  }) async {
    final record = memory['$serial+$userId'];
    return [?record?.counter];
  }

  @override
  Future<void> updateRefreshTokenCounter({
    required String serial,
    required String userId,
    required DateTime lastUpdate,
    required num counter,
  }) async {
    final record = memory['$serial+$userId'];
    if (record == null) throw 'missing record';

    memory['$serial+$userId'] = (
      serial: record.serial,
      userId: record.userId,
      initial: record.initial,
      lastUpdate: lastUpdate,
      counter: counter,
      name: record.name,
    );
  }
}

/// Internal data record for storing token metadata in memory.
typedef MemoryRecord = ({
  String serial,
  String userId,
  DateTime initial,
  DateTime lastUpdate,
  num counter,
  String name,
});
