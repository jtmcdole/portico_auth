import 'package:clock/clock.dart';
import 'package:portico_auth_tokens/src/token_exceptions.dart';
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
  DateTime currentTime() {
    return now;
  }

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

  test('generates well formed access token', () async {
    final token = authService.generateAccessToken(
      kUserId,
      name: 'testing test tester',
      serial: '12345',
    );

    final jwt = JsonWebSignature.fromCompactSerialization(token);
    expect(jwt.verify(store), completion(true));
    final payload = await jwt.getPayload(store);
    expect(
      payload.jsonContent['iat'],
      clock.now().millisecondsSinceEpoch ~/ 1000,
    );
    expect(
      payload.jsonContent['exp'],
      clock.now().millisecondsSinceEpoch ~/ 1000 + Duration.secondsPerHour,
    );
    expect(payload.jsonContent['aud'], kAudience);
    expect(payload.jsonContent['iss'], kIssuer);

    expect(authService.getUserId(token), completion("john@doe.net"));
  });

  group('getPayload', () {
    test('handles expired tokens', () {
      final token = authService.generateAccessToken(
        kUserId,
        name: 'testing test tester',
        serial: '12345',
      );
      now = now.add(Duration(hours: 2));
      expect(authService.getPayload(token), throwsA(isA<AccessTokenInvalid>()));
    });

    test('handles invalid issuer (reuse of keys across multiple sites)', () {
      final token = authService.generateAccessToken(
        kUserId,
        name: 'testing test tester',
        serial: '12345',
      );

      authService = AuthTokensManager(
        key,
        jwtEncryptingKey,
        memoryStorage,
        issuer: 'another issuer',
        audience: kAudience,
        clock: clock,
      );

      expect(authService.getPayload(token), throwsA(isA<AccessTokenInvalid>()));
    });

    test('handles invalid audience (reuse of keys across multiple sites)', () {
      final token = authService.generateAccessToken(
        kUserId,
        name: 'testing test tester',
        serial: '12345',
      );

      authService = AuthTokensManager(
        key,
        jwtEncryptingKey,
        memoryStorage,
        issuer: kIssuer,
        audience: '$kAudience+Failed',
        clock: clock,
      );

      expect(authService.getPayload(token), throwsA(isA<AccessTokenInvalid>()));
    });
  });

  group('newAccessToken', () {
    test('fails on expired refresh token', () async {
      expect(memoryStorage.memory, isEmpty);
      final mint = await authService.mintTokens(
        kUserId,
        name: 'testing test tester',
      );
      expect(memoryStorage.memory, isNotEmpty);

      now = now.add(const Duration(days: 61));
      expect(
        authService.newAccessToken(mint.refreshToken),
        throwsA(isA<RefreshTokenInvalid>()),
      );
    });

    test('fails on token reuse', () async {
      expect(memoryStorage.memory, isEmpty);
      final mint = await authService.mintTokens(
        kUserId,
        name: 'testing test tester',
      );
      expect(memoryStorage.memory, isNotEmpty);

      await expectLater(
        authService.newAccessToken(mint.refreshToken),
        completes,
      );

      await expectLater(
        authService.newAccessToken(mint.refreshToken),
        throwsA(isA<RefreshTokenInvalid>()),
      );
      await expectLater(
        authService.newAccessToken(mint.refreshToken),
        throwsA(isA<RefreshTokenInvalid>()),
      );
    });

    test('exchanges tokens', () async {
      expect(memoryStorage.memory, isEmpty);
      final tokenSet = await authService.mintTokens(kUserId, name: '');
      expect(memoryStorage.memory, isNotEmpty);

      final tokenSet2 = await authService.newAccessToken(tokenSet.refreshToken);
      final payload = await authService.getPayload(
        tokenSet2.refreshToken,
        isRefreshToken: true,
      );
      expect(payload.jsonContent['name'], isNotEmpty);
      expect(
        memoryStorage.memory,
        contains('${payload.jsonContent['serial']}+$kUserId'),
      );
      expect(payload.jsonContent['counter'], 2);
    });
  });

  group('temp tokens', () {
    test('can be generated', () async {
      final mint = await authService.mintTokens(
        kUserId,
        name: 'testing test tester',
      );
      final tempToken = await authService.generateTempToken(mint.accessToken);
      expect(tempToken, isNotEmpty);
      final payload = await authService.getPayload(tempToken);
      final data = payload.jsonContent;
      expect(data['sub'], kUserId);
      expect(data['jti'], isNotNull);
    });

    test('cannot be used to make more temp tokens', () async {
      final mint = await authService.mintTokens(
        kUserId,
        name: 'testing test tester',
      );
      final tempToken = await authService.generateTempToken(mint.accessToken);
      final tempToken2 = authService.generateTempToken(tempToken);
      expect(tempToken2, throwsA(isA<AccessTokenInvalid>()));
    });

    test('like cheese, will expire', () async {
      final mint = await authService.mintTokens(
        kUserId,
        name: 'testing test tester',
      );
      await authService.generateTempToken(
        mint.accessToken,
        expiresIn: Duration(seconds: 1),
      );
      expect(authService.oneTimeTokens, isNotEmpty);
      // Maybe use fake_async?
      await Future.delayed(const Duration(seconds: 2));
      expect(authService.oneTimeTokens, isEmpty);
    });
  });
}
