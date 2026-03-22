import 'dart:convert';
import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_server_shelf/portico_auth_server_shelf.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:jose_plus/jose.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'test_hasher.dart';

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

  late AuthTokensInMemoryStorage tokenStorage;
  late AuthTokensManager tokenManager;
  late AuthCredentialsManager credentials;
  late AuthCredentialsInMemoryStorage credentialStorage;
  late AuthShelf shelfService;
  late AuthRolesInMemoryStorage rolesStorage;
  late AuthRoleManager roleManager;

  setUp(() {
    tokenStorage = AuthTokensInMemoryStorage();
    tokenManager = AuthTokensManager(
      key,
      jwtEncryptingKey,
      tokenStorage,
      issuer: kIssuer,
      audience: kAudience,
    );
    credentialStorage = AuthCredentialsInMemoryStorage();
    credentials = AuthCredentialsManager(
      storage: credentialStorage,
      hasher: ArgonTestHash(),
    );

    rolesStorage = AuthRolesInMemoryStorage();
    roleManager = AuthRoleManager(rolesStorage);

    shelfService = AuthShelf(
      tokenManager,
      credentials: credentials,
      roles: roleManager,
    );
  });

  group('register', () {
    test('successfully registers a user', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/register'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'user_id': 'test@example.com',
          'password': 'password123',
        }),
      );

      final response = await shelfService.register(request);

      expect(response.statusCode, 201);

      // Verify user exists in storage
      final user = await credentialStorage.getPasswordHash('test@example.com');
      expect(user, isNotNull);
    });

    test('returns 400 for invalid JSON', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/register'),
        headers: {'content-type': 'application/json'},
        body: 'invalid-json',
      );

      final response = await shelfService.register(request);

      expect(response.statusCode, 400);
    });

    test('returns 400 for missing fields', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/register'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'user_id': 'test@example.com'}),
      );

      final response = await shelfService.register(request);

      expect(response.statusCode, 400);
    });

    test('returns 409 if user already exists', () async {
      await credentials.registerUser('test@example.com', 'password123');

      final request = Request(
        'POST',
        Uri.parse('http://localhost/register'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'user_id': 'test@example.com',
          'password': 'password123',
        }),
      );

      final response = await shelfService.register(request);

      expect(response.statusCode, 409);
    });
  });
}
