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
  late JsonWebKeyStore jwkStore;

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

    jwkStore = JsonWebKeyStore()..addKey(key);
  });

  group('login', () {
    test('successfully logs in and returns tokens', () async {
      await credentials.registerUser('test@example.com', 'password123');

      final request = Request(
        'POST',
        Uri.parse('http://localhost/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'user_id': 'test@example.com',
          'password': 'password123',
        }),
      );

      final response = await shelfService.login(request);

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body['access_token'], isNotNull);
      expect(body['refresh_token'], isNotNull);
    });

    test('includes active roles in access token', () async {
      // 1. Setup user and role
      const userId = 'admin@example.com';
      await credentials.registerUser(userId, 'password123');
      await roleManager.createRole(
        name: 'admin',
        displayName: 'Admin',
        description: 'Root',
      );
      await roleManager.assignRoleToUser(
        userId: userId,
        roleName: 'admin',
        scope: 'global',
      );
      await roleManager.createRole(
        name: 'fuzz',
        displayName: 'Fuzz',
        description: 'Fuzz Test',
        isActive: false,
      );
      await roleManager.assignRoleToUser(
        userId: userId,
        roleName: 'fuzz',
        scope: 'global',
      );

      // 2. Login
      final request = Request(
        'POST',
        Uri.parse('http://localhost/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'password': 'password123'}),
      );

      final response = await shelfService.login(request);
      final body = jsonDecode(await response.readAsString());
      final accessToken = body['access_token'] as String;

      // 3. Verify Token
      final jwt = JsonWebSignature.fromCompactSerialization(accessToken);
      final payload = await jwt.getPayload(jwkStore);
      final roles = payload.jsonContent['roles'] as List;

      expect(roles, hasLength(1));
      expect(roles.first['role'], equals('admin'));
      expect(roles.first['scope'], equals('global'));
    });

    test('returns 401 for invalid credentials', () async {
      await credentials.registerUser('test@example.com', 'password123');

      final request = Request(
        'POST',
        Uri.parse('http://localhost/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'user_id': 'test@example.com',
          'password': 'wrongpassword',
        }),
      );

      final response = await shelfService.login(request);

      expect(response.statusCode, 401);
    });

    test('returns 401 for non-existent user', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'user_id': 'nonexistent@example.com',
          'password': 'password123',
        }),
      );

      final response = await shelfService.login(request);

      expect(response.statusCode, 401);
    });

    test('returns 400 for missing fields', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/login'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'user_id': 'test@example.com'}),
      );

      final response = await shelfService.login(request);

      expect(response.statusCode, 400);
    });

    test('errors on invalid body', () async {
      await credentials.registerUser('test@example.com', 'password123');

      final request = Request(
        'POST',
        Uri.parse('http://localhost/login'),
        headers: {'content-type': 'application/json'},
        body: 'derp',
      );

      final response = await shelfService.login(request);
      expect(response.statusCode, 400);
    });
  });
}
