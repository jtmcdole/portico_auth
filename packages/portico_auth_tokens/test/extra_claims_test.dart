import 'package:clock/clock.dart';
import 'package:portico_auth_tokens/src/tokens_in_memory_storage.dart';
import 'package:portico_auth_tokens/src/tokens_manager.dart'
    show AuthTokensManager;
import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

const kIssuer = 'https://example.com';
const kAudience = 'https://example.org';

void main() {
  final key = JsonWebKey.fromJson({
    "kty": "EC",
    "d": "6mZX_NYyQfpg5grsN9yVXPKC0bbDwssQq1Pcp6DoMM6BKiYk1jhLcOvMfT2rAvC6",
    "x": "_dgoKttfIy6e9upts1Lm3y7G1RnXuYBVq2UhfqjP3BUW1F__1tAHqklsyYqDbOts",
    "y": "J5tM86kEmS4JOoThkkxZAnPwAJ_oE5OHU_NzmkXYLLeVc_1d7AR4toH8k6iKSa-w",
    "crv": "P-384",
    "alg": "ES384",
    "use": "sig",
    "keyOperations": ["sign", "verify"],
  })!;
  final store = JsonWebKeyStore()..addKey(key);
  final jwtEncryptingKey = JsonWebKey.fromJson({
    "kty": "oct",
    "k": "Va9bvh20Q_ncW-macIma8yjZ79aJSCKN",
    "alg": "A192KW",
    "use": "key",
    "keyOperations": ["wrapKey", "unwrapKey"],
  })!;

  late AuthTokensInMemoryStorage memoryStorage;
  late AuthTokensManager authService;
  late Clock clock;
  late DateTime now;
  DateTime currentTime() => now;

  setUp(() {
    now = DateTime.parse('2024-01-01');
    memoryStorage = AuthTokensInMemoryStorage();
    clock = Clock(currentTime);
    authService = AuthTokensManager(
      key,
      jwtEncryptingKey,
      memoryStorage,
      issuer: kIssuer,
      audience: kAudience,
      clock: clock,
    );
  });

  const kUserId = 'john@doe.net';

  group('Extra Claims', () {
    test('mintTokens includes extraClaims in access token', () async {
      final claims = {'role': 'admin', 'custom_id': 123};
      final tokens = await authService.mintTokens(kUserId, extraClaims: claims);

      final jwt = JsonWebSignature.fromCompactSerialization(tokens.accessToken);
      final payload = await jwt.getPayload(store);

      expect(payload.jsonContent['role'], equals('admin'));
      expect(payload.jsonContent['custom_id'], equals(123));
    });

    test('newAccessToken includes extraClaims in access token', () async {
      // 1. Mint initial tokens
      final tokens = await authService.mintTokens(kUserId);
      final refreshToken = tokens.refreshToken;

      // 2. Refresh with new claims
      final newClaims = {'role': 'moderator', 'scope': 'game_1'};
      final newTokens = await authService.newAccessToken(
        refreshToken,
        extraClaims: newClaims,
      );

      final jwt = JsonWebSignature.fromCompactSerialization(
        newTokens.accessToken,
      );
      final payload = await jwt.getPayload(store);

      expect(payload.jsonContent['role'], equals('moderator'));
      expect(payload.jsonContent['scope'], equals('game_1'));
    });

    test('generateTempToken includes extraClaims', () async {
      final tokens = await authService.mintTokens(kUserId);
      final accessToken = tokens.accessToken;

      final extraClaims = {'temp_usage': 'push_notification'};
      final tempToken = await authService.generateTempToken(
        accessToken,
        extraClaims: extraClaims,
      );

      final jwt = JsonWebSignature.fromCompactSerialization(tempToken);
      final payload = await jwt.getPayload(store);

      expect(payload.jsonContent['temp_usage'], equals('push_notification'));
    });
  });
}
