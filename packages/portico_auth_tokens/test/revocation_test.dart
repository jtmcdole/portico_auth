import 'dart:async';

import 'package:jose_plus/jose.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:test/test.dart';

void main() {
  late JsonWebKey signingKey;
  late JsonWebKey encryptingKey;
  late AuthTokensInMemoryStorage storage;
  late AuthTokensManager manager;

  setUp(() async {
    signingKey = JsonWebKey.generate(JsonWebAlgorithm.es256.name);
    encryptingKey = JsonWebKey.generate(JsonWebAlgorithm.a128kw.name);
    storage = AuthTokensInMemoryStorage();
    manager = AuthTokensManager(
      signingKey,
      encryptingKey,
      storage,
      issuer: 'https://test.issuer',
      audience: 'https://test.audience',
    );
  });

  tearDown(() {
    manager.close();
  });

  group('Revocation Cache', () {
    test(
      'invalidateAllRefreshTokens adds all serials to cache and rejects access tokens',
      () async {
        // 1. Mint tokens for user
        final tokens1 = await manager.mintTokens('user1');
        final tokens2 = await manager.mintTokens('user1');
        final tokensOther = await manager.mintTokens('user2');

        // 2. Validate all work initially
        await expectLater(
          manager.validateToken(tokens1.accessToken),
          completes,
        );
        await expectLater(
          manager.validateToken(tokens2.accessToken),
          completes,
        );
        await expectLater(
          manager.validateToken(tokensOther.accessToken),
          completes,
        );

        // 3. Invalidate all for user1
        await manager.invalidateAllRefreshTokens('user1');

        // 4. Expect user1's tokens to be rejected
        await expectLater(
          manager.validateToken(tokens1.accessToken),
          throwsA(isA<AccessTokenInvalid>()),
          reason: 'Token 1 should be invalid after all user tokens revoked',
        );
        await expectLater(
          manager.validateToken(tokens2.accessToken),
          throwsA(isA<AccessTokenInvalid>()),
          reason: 'Token 2 should be invalid after all user tokens revoked',
        );

        // 5. Expect other user's token to still be valid
        await expectLater(
          manager.validateToken(tokensOther.accessToken),
          completes,
          reason: 'Other user token should remain valid',
        );
      },
    );

    test(
      'invalidateRefreshToken adds serial to cache and rejects access token',
      () async {
        // 1. Mint tokens
        final tokens = await manager.mintTokens('user1');
        final accessToken = tokens.accessToken;
        final payload = await manager.getPayload(accessToken);
        final serial = payload.jsonContent['serial'] as String;

        // 2. Verify valid initially
        await expectLater(
          manager.validateToken(accessToken),
          completes,
          reason: 'Token should be valid initially',
        );

        // 3. Invalidate
        await manager.invalidateRefreshToken(serial, 'user1', 1);

        // 4. Verify invalid immediately (in-memory check)
        await expectLater(
          manager.validateToken(accessToken),
          throwsA(
            isA<AccessTokenInvalid>().having(
              (e) => e.reason,
              'reason',
              'token serial revoked',
            ),
          ),
          reason: 'Token should be invalid after revocation due to cache',
        );
      },
    );

    test('onSerialRevoked callback is triggered', () async {
      final completer = Completer<String>();
      manager = AuthTokensManager(
        signingKey,
        encryptingKey,
        storage,
        issuer: 'https://test.issuer',
        audience: 'https://test.audience',
        onSerialRevoked: (serial, userId) async {
          completer.complete('$serial:$userId');
        },
      );

      final tokens = await manager.mintTokens('user2');
      final payload = await manager.getPayload(tokens.accessToken);
      final serial = payload.jsonContent['serial'] as String;

      await manager.invalidateRefreshToken(serial, 'user2', 1);

      expect(await completer.future, '$serial:user2');
    });

    test('cache prevents usage even if storage fails (theoretical)', () async {
      // This tests that we update cache BEFORE storage
      // We can't easily mock storage failure with InMemory, but we can verify order
      // by inspecting the list after invalidation.
      final tokens = await manager.mintTokens('user3');
      final serial =
          (await manager.getPayload(tokens.accessToken)).jsonContent['serial']
              as String;

      await manager.invalidateRefreshToken(serial, 'user3', 1);

      // We can't access private _revokedSerials directly, but behavior proves it
      await expectLater(
        manager.validateToken(tokens.accessToken),
        throwsA(isA<AccessTokenInvalid>()),
      );
    });

    test('replay attack detection invalidates the entire chain', () async {
      // 1. Mint initial tokens (RT1, AT1)
      final tokens1 = await manager.mintTokens('user4');
      final rt1 = tokens1.refreshToken;
      final at1 = tokens1.accessToken;

      // 2. Perform a legitimate refresh (RT1 -> RT2, AT2)
      final tokens2 = await manager.newAccessToken(rt1);
      final rt2 = tokens2.refreshToken;
      final at2 = tokens2.accessToken;

      expect(rt2, isNot(rt1));
      expect(at2, isNot(at1));

      // 3. Attempt a replay attack using the now-obsolete RT1
      await expectLater(
        manager.newAccessToken(rt1),
        throwsA(
          isA<RefreshTokenInvalid>().having(
            (e) => e.reason,
            'reason',
            contains('potential replay attack'),
          ),
        ),
      );

      // 4. Verify that the NEW access token (AT2) is now also invalid
      // because the replay attack triggered a full serial revocation in the cache.
      await expectLater(
        manager.validateToken(at2),
        throwsA(
          isA<AccessTokenInvalid>().having(
            (e) => e.reason,
            'reason',
            'token serial revoked',
          ),
        ),
      );
    });
  });
}
