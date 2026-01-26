import 'dart:async';

import 'package:clock/clock.dart';
import 'package:logging/logging.dart';
import 'package:jose_plus/jose.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';
import 'package:namer/namer.dart' as namer;

import 'tokens_storage_adapter.dart';
import 'token_exceptions.dart';
import 'token_record.dart';
import 'token_set.dart';

/// A service that handles authentication using JWTs (JSON Web Tokens).
///
/// This service is responsible for:
/// * Minting access and refresh tokens.
/// * Validating tokens.
/// * Managing token lifecycles (expiration, rotation).
/// * Generating temporary tokens for specific actions.
///
/// It uses [AuthTokensStorageAdapter] to persist token metadata (like revocation lists)
/// and cryptographic operations (signing and encryption).
class AuthTokensManager {
  static final log = Logger('auth.server');

  /// The key used to sign access tokens (JWS).
  final JsonWebKey signingKey;

  /// The key used to encrypt refresh tokens (JWE).
  final JsonWebKey encryptingKey;

  /// [RFC-7519 Issuer](https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.1)
  ///
  /// > The "iss" (issuer) claim identifies the principal that issued the
  /// > JWT.  The processing of this claim is generally application specific.
  /// > The "iss" value is a case-sensitive string containing a StringOrURI
  /// > value.  Use of this claim is OPTIONAL.
  final String issuer;

  /// [RFC-7519 Audience](https://datatracker.ietf.org/doc/html/rfc7519#section-4.1.3)
  ///
  /// > The "aud" (audience) claim identifies the recipients that the JWT is
  /// > intended for.  Each principal intended to process the JWT MUST
  /// > identify itself with a value in the audience claim.  If the principal
  /// > processing the claim does not identify itself with a value in the
  /// > "aud" claim when this claim is present, then the JWT MUST be
  /// > rejected.  In the general case, the "aud" value is an array of case-
  /// > sensitive strings, each containing a StringOrURI value.  In the
  /// > special case when the JWT has one audience, the "aud" value MAY be a
  /// > single case-sensitive string containing a StringOrURI value.  The
  /// > interpretation of audience values is generally application specific.
  /// > Use of this claim is OPTIONAL.
  final String audience;

  late final JsonWebKeyStore jwkStore;

  /// The storage adapter for persisting token data.
  final AuthTokensStorageAdapter storage;

  /// These tokens will only live for a very short time.
  final oneTimeTokens = <String>{};

  /// Life span of a temporary token before its removed.
  final Duration tempTokenLifetime;

  /// The maximum duration a refresh token is valid.
  final Duration maxRefreshTokenLifetime;

  /// Optional callback for when a serial is revoked (e.g. replay attack or logout).
  /// This allows external systems (like Redis) to be notified.
  final Future<void> Function(String serial, String userId)? onSerialRevoked;

  final Clock clock;
  static final _uuid = const Uuid();

  // --- Revocation Cache (Generational) ---
  // We keep two sets: current and previous. Every hour, we rotate.
  // This ensures a revoked serial stays in memory for at least 1 hour
  // (matching the default Access Token lifetime) and at most 2 hours.
  var _revokedSerials = <String>{};
  var _prevRevokedSerials = <String>{};
  Timer? _cleanupTimer;

  /// Creates a new [AuthTokensManager].
  ///
  /// Requires a [signingKey] for JWS and an [encryptingKey] for JWE.
  /// [storage] is used to persist token state.
  ///
  /// [issuer] and [audience] are required JWT claims (RFC 7519).
  ///
  /// Optionally:
  ///   * Define the duration of the [tempTokenLifetime] - shorter is better.
  ///   * Override the [maxRefreshTokenLifetime].
  ///   * Provide [onSerialRevoked] to handle revocation events externally.
  AuthTokensManager(
    this.signingKey,
    this.encryptingKey,
    this.storage, {
    required this.issuer,
    required this.audience,
    this.tempTokenLifetime = const Duration(seconds: 30),
    this.maxRefreshTokenLifetime = const Duration(days: 60),
    this.onSerialRevoked,
    @visibleForTesting this.clock = const Clock(),
  }) {
    jwkStore = JsonWebKeyStore()
      ..addKey(signingKey)
      ..addKey(encryptingKey);

    // Start the cleanup timer (1 hour rotation)
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      _prevRevokedSerials = _revokedSerials;
      _revokedSerials = <String>{};
    });
  }

  /// Dispose of the cleanup timer.
  void close() {
    _cleanupTimer?.cancel();
  }

  /// Generate a temporary token for [accessToken] that will expire.
  ///
  /// This should only be called from authenticated locations.
  Future<String> generateTempToken(
    String accessToken, {
    Duration? expiresIn,
    Map<String, dynamic> extraClaims = const <String, dynamic>{},
  }) async {
    final tokenData = await getPayload(accessToken);
    if (tokenData.jsonContent case {
      'sub': String subject,
      'name': String name,
      'serial': String serial,
    }) {
      if (tokenData.jsonContent['jti'] != null) {
        throw AccessTokenInvalid('temp token used to generate a temp token');
      }
      final jwtId = _uuid.v4();
      final jwt = generateAccessToken(
        subject,
        name: name,
        serial: serial,
        expiresIn: (expiresIn ?? tempTokenLifetime),
        extraClaims: {
          // mark this jwt as single-use
          'jti': jwtId,
          ...extraClaims,
        },
      );

      // This core piece of code will make sure the token cannot be used after 30s.
      // It is also a one-time live token with jti (we remove it on validation)
      Future.delayed(expiresIn ?? tempTokenLifetime).then((_) {
        oneTimeTokens.remove(jwtId);
      });
      oneTimeTokens.add(jwtId);
      return jwt;
    }
    throw AccessTokenInvalid('Expecting access token');
  }

  /// Generates an access token for the [userId].
  @visibleForTesting
  String generateAccessToken(
    String userId, {
    required String name,
    required String serial,
    Duration expiresIn = const Duration(hours: 1),
    Map<String, dynamic> extraClaims = const <String, dynamic>{},
  }) {
    final builder = JsonWebSignatureBuilder();
    final now = clock.now().secondsSinceEpoch;
    final baseClaims = {
      'iat': now,
      'exp': now + expiresIn.inSeconds,
      'aud': audience,
      'iss': issuer,
      'sub': userId,
      'name': name,
      'serial': serial,
    };
    // order: don't let extra claims stomp on our base claims.
    final claims = <String, dynamic>{}
      ..addAll(extraClaims)
      ..addAll(baseClaims);
    builder.jsonContent = JsonWebTokenClaims.fromJson(claims);
    builder.addRecipient(signingKey);
    return builder.build().toCompactSerialization();
  }

  /// Returns a basic validated payload from [token].
  Future<JosePayload> getPayload(
    String token, {
    bool isRefreshToken = false,
  }) async {
    final JoseObject jwt;
    try {
      jwt = isRefreshToken
          ? JsonWebEncryption.fromCompactSerialization(token)
          : JsonWebSignature.fromCompactSerialization(token);
    } catch (e) {
      throw (isRefreshToken ? RefreshTokenInvalid.new : AccessTokenInvalid.new)(
        'invalid token format',
      );
    }
    final payload = await jwt.getPayload(jwkStore);
    final json = payload.jsonContent;
    if (json case {
      'sub': String _,
      'exp': num expiration,
      'iss': String issuer,
      'aud': String audience,
      'serial': String serial,
    }) {
      if (clock.now().secondsSinceEpoch > expiration) {
        throw (isRefreshToken
            ? RefreshTokenInvalid.new
            : AccessTokenInvalid.new)('expired jwt');
      }
      if (issuer != this.issuer) {
        throw (isRefreshToken
            ? RefreshTokenInvalid.new
            : AccessTokenInvalid.new)('invalid issuer');
      }
      if (audience != this.audience) {
        throw (isRefreshToken
            ? RefreshTokenInvalid.new
            : AccessTokenInvalid.new)('invalid audience');
      }

      // Check Revocation Cache (In-Memory Check)
      if (_revokedSerials.contains(serial) ||
          _prevRevokedSerials.contains(serial)) {
        throw (isRefreshToken
            ? RefreshTokenInvalid.new
            : AccessTokenInvalid.new)('token serial revoked');
      }

      // Remove temporary tokens.
      if (json case {'jti': String jtiId}) {
        if (oneTimeTokens.remove(jtiId) != true) {
          throw AccessTokenInvalid('re-use of one-time jwt');
        }
      }

      return payload;
    }
    throw AccessTokenInvalid('missing expected payloads');
  }

  /// Validates a [token] and returns a [TokenRecord].
  ///
  /// Set [isRefreshToken] to true if the token is expected to be a JWE refresh token.
  Future<TokenRecord> validateToken(
    String token, {
    bool isRefreshToken = false,
  }) async {
    final payload = await getPayload(token, isRefreshToken: isRefreshToken);
    final json = payload.jsonContent;
    return TokenRecord(
      userId: json['sub'] as String,
      name: json['name'] as String,
      serial: json['serial'] as String,
      claims: json,
    );
  }

  /// Retrieves the user identifier from a given token
  Future<String> getUserId(String token) async {
    final subject = (await getPayload(token)).jsonContent['sub'];
    return subject;
  }

  /// Removes a token serial number from the database
  Future<void> invalidateRefreshToken(
    String serial,
    String userId,
    num counter,
  ) async {
    log.severe(
      'killing refresh token serial chain: $serial, $userId, $counter',
    );
    // Add to in-memory revocation cache
    _revokedSerials.add(serial);
    // Notify external listeners
    onSerialRevoked?.call(serial, userId);

    await storage.invalidateRefreshToken(serial: serial, userId: userId);
  }

  /// Mint a new token set.
  ///
  /// This operation is done at login time when a user exchanges a username
  /// and password.
  Future<TokenSet> mintTokens(
    String userId, {
    String name = '',
    Map<String, dynamic> extraClaims = const <String, dynamic>{},
  }) async {
    final now = clock.now();
    final serial = _uuid.v4();
    final builder = JsonWebEncryptionBuilder();

    final named = name.isNotEmpty
        ? name
        : namer.generic(adjectives: 1, verbs: 1);

    builder.setProtectedHeader('createdAt', DateTime.now().toIso8601String());

    builder.jsonContent = JsonWebTokenClaims.fromJson({
      'iat': now.secondsSinceEpoch,
      'exp': now.secondsSinceEpoch + maxRefreshTokenLifetime.inSeconds,
      'aud': audience,
      'iss': issuer,
      'sub': userId,
      'counter': 1,
      'serial': serial,
      'name': named,
    });

    builder.addRecipient(encryptingKey);
    final jwe = builder.build();
    await storage.recordRefreshToken(
      serial: serial,
      userId: userId,
      initial: now,
      lastUpdate: now,
      name: named,
      counter: 1,
    );

    final expiresIn = const Duration(hours: 1);
    final jwt = generateAccessToken(
      userId,
      name: named,
      serial: serial,
      expiresIn: expiresIn,
      extraClaims: extraClaims,
    );
    return TokenSet(
      refreshToken: jwe.toCompactSerialization(),
      accessToken: jwt,
      expirationDate: now.add(expiresIn),
      name: named,
    );
  }

  /// Exchanges a [refreshToken] for a new refresh and access token.
  ///
  /// The refresh token (RT) is a JSON web encryption token (JWE). Its job is
  /// to exist for generating a new access token (signed JWT). Each JWE has a
  /// serial number, counter, sub, and expiration. The counter serves to
  /// detect replay attacks (stolen tokens) and lets the system invalidate
  /// the token serial if detected; the attacker and user will lose access.
  ///
  /// While a RT can live for days; the AT lives for a short period of time.
  /// This means while the user is active, the RT will only live for as long
  /// as the AT. While the user is inactive, the AT will expire and the RT
  /// will be needed before any authorized calls can be made.
  Future<TokenSet> newAccessToken(
    String refreshToken, {
    Map<String, dynamic> extraClaims = const <String, dynamic>{},
  }) async {
    final payload = await getPayload(refreshToken, isRefreshToken: true);
    final content = payload.jsonContent;
    if (content case {
      'serial': String serial,
      'counter': num counter,
      'sub': String userId,
      'iss': String issuer,
      'aud': String audience,
      'name': String name,
    }) {
      //----  BEGIN TOKEN VALIDATION

      // Validate counter matches
      final counters = await storage.getRefreshTokenCounter(
        serial: serial,
        userId: userId,
      );

      // Someone is trying to re-used an invalidated token chain
      if (counters.isEmpty) {
        throw RefreshTokenInvalid(
          'refresh token serial invalid (replay attack?): $serial / $userId',
        );
      }

      if (counters.length > 1) {
        throw RefreshTokenInvalid('too many counters - BUG: $serial / $userId');
      }

      // Someone is trying to replay a token
      if (counters.first != counter) {
        _revokedSerials.add(serial);
        await invalidateRefreshToken(serial, userId, counter);
        throw RefreshTokenInvalid('potential replay attack: $serial / $userId');
      }
      //----  END OF VALIDATION

      //----  Create new JWE and update records
      final newCounter = counter + 1;
      final builder = JsonWebEncryptionBuilder();
      final now = clock.now();
      builder.jsonContent = JsonWebTokenClaims.fromJson({
        'iat': now.secondsSinceEpoch,
        'exp': now.secondsSinceEpoch + maxRefreshTokenLifetime.inSeconds,
        'aud': audience,
        'iss': issuer,
        'sub': userId,
        'counter': newCounter,
        'serial': serial,
        'name': name,
      });
      builder.addRecipient(encryptingKey);
      final jwe = builder.build();
      await storage.updateRefreshTokenCounter(
        serial: serial,
        userId: userId,
        lastUpdate: now,
        counter: newCounter,
      );

      //----  Create new access token and return the pairing
      final expiresIn = const Duration(hours: 1);
      return TokenSet(
        refreshToken: jwe.toCompactSerialization(),
        accessToken: generateAccessToken(
          userId,
          name: name,
          serial: serial,
          expiresIn: expiresIn,
          extraClaims: extraClaims,
        ),
        expirationDate: now.add(expiresIn),
        name: name,
      );
    }

    throw RefreshTokenInvalid('failure');
  }
}

extension SecondsSinceEpoch on DateTime {
  int get secondsSinceEpoch => millisecondsSinceEpoch ~/ 1000;
}
