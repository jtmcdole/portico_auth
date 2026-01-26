import 'dart:async';
import 'dart:convert';

import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_tokens/src/tokens_in_memory_storage.dart';
import 'package:portico_auth_tokens/src/tokens_manager.dart'
    show AuthTokensManager;
import 'package:portico_auth_server_shelf/portico_auth_server_shelf.dart';
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

  late AuthTokensInMemoryStorage memoryStorage;
  late AuthTokensManager authService;
  late AuthShelf shelfService;
  late AuthRolesInMemoryStorage rolesStorage;
  late AuthRoleManager roleManager;

  setUp(() async {
    memoryStorage = AuthTokensInMemoryStorage();
    authService = AuthTokensManager(
      key,
      jwtEncryptingKey,
      memoryStorage,
      issuer: kIssuer,
      audience: kAudience,
    );
    final credStorage = AuthCredentialsInMemoryStorage();
    final credService = AuthCredentialsManager(storage: credStorage);
    await credService.registerUser('john@doe.net', 'password');

    rolesStorage = AuthRolesInMemoryStorage();
    roleManager = AuthRoleManager(rolesStorage);

    shelfService = AuthShelf(
      authService,
      credentials: credService,
      roles: roleManager,
    );
  });

  group('middleware', () {
    late FutureOr<Response> Function(Request) handler;

    setUp(() {
      handler = shelfService.middleware((request) {
        return Response.ok(null);
      });
    });

    test('returns unauthorized when missing headers', () async {
      expectUnauthorized(response) async {
        expect(response, completes);
        var sup = await response;
        expect(sup.statusCode, 401);
        expect(sup.readAsString(), completion('Unauthorized'));
      }

      await expectUnauthorized(
        handler(Request('PUT', Uri.parse('https://example.com/api/fu'))),
      );
      await expectUnauthorized(
        handler(
          Request(
            'PUT',
            Uri.parse('https://example.com/api/fu'),
            headers: {'authorization': 'Breakers'},
          ),
        ),
      );
      await expectUnauthorized(
        handler(
          Request(
            'PUT',
            Uri.parse('https://example.com/api/fu?authorization=Breaker'),
          ),
        ),
      );
    });

    test('removes one-time use tokens', () async {
      final token = authService.generateAccessToken(
        'john@doe.net',
        name: 'testing test tester',
        serial: '12345',
        extraClaims: {
          'random': ['api/fu', 'api/bar'],
        },
      );

      expect(authService.oneTimeTokens, isEmpty);

      final tempToken = await authService.generateTempToken(token);

      expect(authService.oneTimeTokens, isNotEmpty);

      var response = handler(
        Request(
          'PUT',
          Uri.parse('https://example.com/api/onetimeuse'),
          headers: {'authorization': 'Bearer $tempToken'},
        ),
      );

      expect(response, completes);
      var sup = await response;
      expect(sup.statusCode, 200);
      expect(authService.oneTimeTokens, isEmpty);
    });
  });

  group('refresh', () {
    test('returns error when missing information', () async {
      final handler = shelfService.refresh;

      var response = await handler(
        Request('PUT', Uri.parse('https://example.com/api/getAccesToken')),
      );
      expect(response.statusCode, 400);
      expect(response.readAsString(), completion('Bad Request'));

      response = await handler(
        Request(
          'PUT',
          Uri.parse('https://example.com/api/getAccesToken'),
          headers: {'content-type': 'application/json'},
          body: '{}',
        ),
      );
      expect(response.statusCode, 400);
      expect(response.readAsString(), completion('Bad Request'));
    });

    test('gets new access and refresh token', () async {
      final initialToken = await authService.mintTokens(
        'john@doe.net',
        name: 'test token',
      );
      final handler = shelfService.refresh;

      var response = await handler(
        Request(
          'PUT',
          Uri.parse('https://example.com/api/getAccesToken'),
          headers: {'content-type': 'application/json'},
          body: '{"refresh_token": "${initialToken.refreshToken}"}',
        ),
      );
      expect(response.statusCode, 200);
      final tokens = json.decode(await response.readAsString());
      expect(tokens, contains('name'));
      expect(tokens, contains('access_token'));
      expect(tokens, contains('refresh_token'));
      expect(tokens['refresh_token'], isNot(initialToken.refreshToken));
    });
  });

  group('logout', () {
    test('returns error when missing information', () async {
      final handler = shelfService.logout;

      var response = await handler(
        Request('PUT', Uri.parse('https://example.com/api/getAccesToken')),
      );
      expect(response.statusCode, 400);
      expect(response.readAsString(), completion('Bad Request'));

      response = await handler(
        Request(
          'PUT',
          Uri.parse('https://example.com/api/getAccesToken'),
          headers: {'content-type': 'application/json'},
          body: '{}',
        ),
      );
      expect(response.statusCode, 400);
      expect(response.readAsString(), completion('Bad Request'));
    });

    test('returns error when bad information', () async {
      final handler = shelfService.logout;

      var response = await handler(
        Request(
          'PUT',
          Uri.parse('https://example.com/api/getAccesToken'),
          headers: {'content-type': 'application/json'},
          body: 'fuzz',
        ),
      );
      expect(response.statusCode, 400);
      expect(response.readAsString(), completion('Bad Request'));
    });

    test('burns the refresh token', () async {
      final initialToken = await authService.mintTokens(
        'john@doe.net',
        name: 'test token',
      );
      final initialPayload =
          (await authService.getPayload(
                initialToken.refreshToken,
                isRefreshToken: true,
              )).jsonContent
              as Map<String, dynamic>;
      final handler = shelfService.logout;
      expect(
        memoryStorage.memory,
        contains('${initialPayload['serial']}+john@doe.net'),
      );
      var response = await handler(
        Request(
          'PUT',
          Uri.parse('https://example.com/api/getAccesToken'),
          headers: {'content-type': 'application/json'},
          body: '{"refresh_token": "${initialToken.refreshToken}"}',
        ),
      );
      expect(response.statusCode, 200);
      expect(response.contentLength, 0);
      expect(memoryStorage.memory, isEmpty);
    });
  });

  group('generateTempToken', () {
    const shortTime = Duration(seconds: 2);

    setUp(() async {
      authService = AuthTokensManager(
        key,
        jwtEncryptingKey,
        memoryStorage,
        issuer: kIssuer,
        audience: kAudience,
        tempTokenLifetime: shortTime,
      );
      final credStorage = AuthCredentialsInMemoryStorage();
      final credService = AuthCredentialsManager(storage: credStorage);
      await credService.registerUser('john@doe.net', 'password');

      rolesStorage = AuthRolesInMemoryStorage();
      roleManager = AuthRoleManager(rolesStorage);

      shelfService = AuthShelf(
        authService,
        credentials: credService,
        roles: roleManager,
      );
    });

    test('for access token', () async {
      final initialToken = authService.generateAccessToken(
        'john@doe.net',
        name: 'testing test tester',
        serial: '12345',
      );

      final handler = shelfService.middleware(shelfService.generateTempToken);

      var response = handler(
        Request(
          'PUT',
          Uri.parse('https://example.com/api/genTempToken'),
          headers: {'authorization': 'Bearer $initialToken'},
        ),
      );

      expect(response, completes);
      final sup = await response;
      expect(sup.statusCode, 200);

      expect(authService.oneTimeTokens, isNotEmpty);

      final body = await sup.readAsString();
      final jwt = JsonWebSignature.fromCompactSerialization(body);
      expect(jwt.verify(authService.jwkStore), completion(true));
      final payload = (await jwt.getPayload(authService.jwkStore)).jsonContent;

      expect(
        payload['exp'],
        equals(payload['iat'] + authService.tempTokenLifetime.inSeconds),
      );
      expect(authService.oneTimeTokens, isNotEmpty);

      await Future.delayed(shortTime);

      expect(authService.oneTimeTokens, isEmpty);
    });

    test('ignores unauthed', () async {
      final handler = shelfService.generateTempToken;
      var response = await handler(
        Request('PUT', Uri.parse('https://example.com/api/genTempToken')),
      );
      expect(response.statusCode, 400);
    });
  });

  group('requiredRole helper with forbiddenRequestHandler', () {
    test('allows access if role is present', () async {
      final token = authService.generateAccessToken(
        'john@doe.net',
        name: 'test',
        serial: '123',
        extraClaims: {
          'roles': [
            {'role': 'admin', 'scope': null},
          ],
        },
      );

      final handler = shelfService.middleware(
        shelfService.exceptionRequestHandler((Request request) {
          shelfService.requiredRole(request, 'admin');
          return Response.ok('Success');
        }),
      );

      final response = await handler(
        Request(
          'GET',
          Uri.parse('https://example.com/admin'),
          headers: {'authorization': 'Bearer $token'},
        ),
      );

      expect(response.statusCode, 200);
    });

    test('returns 403 if role is missing', () async {
      final token = authService.generateAccessToken(
        'john@doe.net',
        name: 'test',
        serial: '123',
      );

      final handler = shelfService.middleware(
        shelfService.exceptionRequestHandler((Request request) {
          shelfService.requiredRole(request, 'admin');
          return Response.ok('Success');
        }),
      );

      final response = await handler(
        Request(
          'GET',
          Uri.parse('https://example.com/admin'),
          headers: {'authorization': 'Bearer $token'},
        ),
      );

      expect(response.statusCode, 403);
      expect(
        response.readAsString(),
        completion(contains('Insufficient permissions')),
      );
    });

    test('returns 401 if missing JWT', () async {
      final handler = shelfService.middleware(
        shelfService.exceptionRequestHandler((Request request) {
          shelfService.requiredRole(request, 'admin');
          return Response.ok('Success');
        }),
      );

      final response = await handler(
        Request('GET', Uri.parse('https://example.com/admin')),
      );

      expect(response.statusCode, 401);
      expect(response.readAsString(), completion(contains('Unauthorized')));
    });

    group('exceptionRequestHandler', () {
      test('converts UnauthorizedException', () async {
        final handler = shelfService.exceptionRequestHandler((Request request) {
          throw UnauthorizedException('asdf');
        });

        final response = await handler(
          Request('GET', Uri.parse('https://example.com/admin')),
        );

        expect(response.statusCode, 401);
        expect(
          response.readAsString(),
          completion(contains('Unauthorized: asdf')),
        );
      });

      test('converts ForbiddenException', () async {
        final handler = shelfService.exceptionRequestHandler((Request request) {
          throw ForbiddenException('asdf');
        });

        final response = await handler(
          Request('GET', Uri.parse('https://example.com/admin')),
        );

        expect(response.statusCode, 403);
        expect(
          response.readAsString(),
          completion(contains('Forbidden: asdf')),
        );
      });

      test('converts anything else to internal', () async {
        final handler = shelfService.exceptionRequestHandler((Request request) {
          throw 'asdf';
        });

        final response = await handler(
          Request('GET', Uri.parse('https://example.com/admin')),
        );

        expect(response.statusCode, 500);
        expect(
          response.readAsString(),
          completion(contains('Internal Server Error')),
        );
      });
    });
  });
}
