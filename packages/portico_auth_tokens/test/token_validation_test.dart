import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:clock/clock.dart';
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

  setUp(() {
    now = DateTime.parse('2024-01-01');
    memoryStorage = AuthTokensInMemoryStorage();
    clock = Clock(() => now);
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

  group('validateToken', () {
    test('validates access token and returns structured record', () async {
      final token = authService.generateAccessToken(
        kUserId,
        name: 'John Doe',
        serial: 'abc-123',
      );

      final record = await authService.validateToken(token);

      expect(record.userId, kUserId);
      expect(record.name, 'John Doe');
      expect(record.serial, 'abc-123');
      expect(record.claims['iss'], kIssuer);
    });

    test('validates refresh token and returns structured record', () async {
      final tokens = await authService.mintTokens(kUserId, name: 'John Doe');
      final refreshToken = tokens.refreshToken;

      final record = await authService.validateToken(
        refreshToken,
        isRefreshToken: true,
      );

      expect(record.userId, kUserId);
      expect(record.name, 'John Doe');
      expect(record.serial, isNotEmpty);
      expect(record.claims['iss'], kIssuer);
    });

    test('throws for invalid access token', () async {
      expect(
        authService.validateToken('invalid-token'),
        throwsA(isA<AccessTokenInvalid>()),
      );
    });
  });
}
