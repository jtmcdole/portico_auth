import 'dart:convert';
import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_server_shelf/portico_auth_server_shelf.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:jose_plus/jose.dart';
import 'package:shelf/shelf.dart';
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
    credentials = AuthCredentialsManager(storage: credentialStorage);

    rolesStorage = AuthRolesInMemoryStorage();
    roleManager = AuthRoleManager(rolesStorage);

    shelfService = AuthShelf(
      tokenManager,
      credentials: credentials,
      roles: roleManager,
    );

    jwkStore = JsonWebKeyStore()..addKey(key);
  });

  group('refresh', () {
    test('successfully refreshes token when user exists', () async {
      await credentials.registerUser('test@example.com', 'password123');
      final tokens = await tokenManager.mintTokens('test@example.com');
      final refreshToken = tokens.refreshToken;

      final request = Request(
        'POST',
        Uri.parse('http://localhost/refresh'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      final response = await shelfService.refresh(request);

      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString());
      expect(body['access_token'], isNotNull);
    });

    test('refreshes token with updated roles', () async {
      const userId = 'user@example.com';
      await credentials.registerUser(userId, 'password123');
      await roleManager.createRole(
        name: 'user',
        displayName: 'User',
        description: 'Basic',
      );

      // 1. Initial login (no roles assigned yet)
      final tokens = await tokenManager.mintTokens(userId);
      final refreshToken = tokens.refreshToken;

      // 2. Assign role
      await roleManager.assignRoleToUser(userId: userId, roleName: 'user');

      // 3. Refresh
      final request = Request(
        'POST',
        Uri.parse('http://localhost/refresh'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      final response = await shelfService.refresh(request);
      final body = jsonDecode(await response.readAsString());
      final accessToken = body['access_token'] as String;

      // 4. Verify new token has roles
      final jwt = JsonWebSignature.fromCompactSerialization(accessToken);
      final payload = await jwt.getPayload(jwkStore);
      final roles = payload.jsonContent['roles'] as List;

      expect(roles, hasLength(1));
      expect(roles.first['role'], equals('user'));
    });

    test('fails to refresh if user was deleted', () async {
      await credentials.registerUser('test@example.com', 'password123');
      final tokens = await tokenManager.mintTokens('test@example.com');
      final refreshToken = tokens.refreshToken;

      // Delete user
      await credentials.deleteUser('test@example.com');

      final request = Request(
        'POST',
        Uri.parse('http://localhost/refresh'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      final response = await shelfService.refresh(request);

      // Should return 401 because user no longer exists
      expect(response.statusCode, 401);
    });

    test('returns 400 for missing refresh_token', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/refresh'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({}),
      );

      final response = await shelfService.refresh(request);

      expect(response.statusCode, 400);
    });

    test('returns 400 for bad data', () async {
      final request = Request(
        'POST',
        Uri.parse('http://localhost/refresh'),
        headers: {'content-type': 'application/json'},
        body: 'fuzz',
      );

      final response = await shelfService.refresh(request);

      expect(response.statusCode, 400);
    });
  });
}
