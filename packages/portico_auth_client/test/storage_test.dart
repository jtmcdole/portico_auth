import 'package:portico_auth_client/src/in_memory_token_storage.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryTokenStorage', () {
    late InMemoryTokenStorage storage;
    final tokens = TokenSet(
      name: 'test',
      accessToken: 'access',
      refreshToken: 'refresh',
      expirationDate: DateTime.now().add(const Duration(hours: 1)),
    );

    setUp(() {
      storage = InMemoryTokenStorage();
    });

    test('saves and loads tokens', () async {
      storage.save(tokens);
      final loaded = await storage.load();
      expect(loaded, equals(tokens));
      expect(loaded?.accessToken, equals('access'));
    });

    test('clears tokens', () async {
      storage.save(tokens);
      storage.clear();
      expect(await storage.load(), isNull);
    });

    test('returns null when no tokens are saved', () async {
      expect(await storage.load(), isNull);
    });
  });
}
