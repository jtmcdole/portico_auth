import 'dart:io';
import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_server_frog/portico_auth_server_frog.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:jose_plus/jose.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockRequestContext extends Mock implements RequestContext {}

class MockRequest extends Mock implements Request {}

void main() {
  group('AuthFrog Integration', () {
    late AuthTokensManager tokens;
    late AuthCredentialsManager credentials;
    late AuthRoleManager roles;
    late AuthFrog authFrog;

    setUpAll(() async {
      final signingKey = JsonWebKey.generate(JsonWebAlgorithm.es384.name);
      final encryptingKey = JsonWebKey.generate(JsonWebAlgorithm.a128kw.name);

      tokens = AuthTokensManager(
        signingKey,
        encryptingKey,
        AuthTokensInMemoryStorage(),
        issuer: 'test-issuer',
        audience: 'test-audience',
      );

      credentials = AuthCredentialsManager(
        storage: AuthCredentialsInMemoryStorage(),
      );
      roles = AuthRoleManager(AuthRolesInMemoryStorage());

      authFrog = AuthFrog(
        tokens: tokens,
        credentials: credentials,
        roles: roles,
      );
    });

    test(
      'Full Flow: Register -> Login -> Authenticate -> Refresh -> Logout',
      () async {
        const username = 'user@example.com';
        const password = 'Password123!';

        // 1. Register
        final registerContext = MockRequestContext();
        final registerRequest = MockRequest();
        when(() => registerContext.request).thenReturn(registerRequest);
        when(
          () => registerRequest.headers,
        ).thenReturn({'content-length': '100'});
        when(
          () => registerRequest.json(),
        ).thenAnswer((_) async => {'user_id': username, 'password': password});

        final registerResponse = await authFrog.register(registerContext);
        expect(registerResponse.statusCode, equals(HttpStatus.ok));
        final userView = await registerResponse.json();
        expect(userView['id'], equals(username));

        // 2. Login
        final loginContext = MockRequestContext();
        final loginRequest = MockRequest();
        when(() => loginContext.request).thenReturn(loginRequest);
        when(() => loginRequest.headers).thenReturn({'content-length': '100'});
        when(
          () => loginRequest.json(),
        ).thenAnswer((_) async => {'user_id': username, 'password': password});

        final loginResponse = await authFrog.login(loginContext);
        expect(loginResponse.statusCode, equals(HttpStatus.ok));
        final loginBody = await loginResponse.json();
        final accessToken = loginBody['access_token'] as String;
        final refreshToken = loginBody['refresh_token'] as String;
        expect(accessToken, isNotEmpty);
        expect(refreshToken, isNotEmpty);

        // 3. Authenticate (Protected Route)
        final protectedContext = MockRequestContext();
        final authenticatedUser = await authFrog.authenticator(
          protectedContext,
          accessToken,
        );
        expect(authenticatedUser, isNotNull);
        expect(authenticatedUser!.id, equals(username));
        expect(authenticatedUser.metadata['serial'], isNotEmpty);
        final serial = authenticatedUser.metadata['serial'] as String;

        // 4. Refresh
        final refreshContext = MockRequestContext();
        final refreshRequest = MockRequest();
        when(() => refreshContext.request).thenReturn(refreshRequest);
        when(
          () => refreshRequest.headers,
        ).thenReturn({'content-length': '100'});
        when(
          () => refreshRequest.json(),
        ).thenAnswer((_) async => {'refresh_token': refreshToken});

        final refreshResponse = await authFrog.refresh(refreshContext);
        expect(refreshResponse.statusCode, equals(HttpStatus.ok));
        final refreshBody = await refreshResponse.json();
        final newAccessToken = refreshBody['access_token'] as String;
        final newRefreshToken = refreshBody['refresh_token'] as String;
        expect(newAccessToken, isNot(equals(accessToken)));
        expect(newRefreshToken, isNot(equals(refreshToken)));

        // 5. Authenticate with new token
        final authenticatedUser2 = await authFrog.authenticator(
          protectedContext,
          newAccessToken,
        );
        expect(authenticatedUser2, isNotNull);
        expect(authenticatedUser2!.id, equals(username));
        expect(authenticatedUser2.metadata['serial'], equals(serial));

        // 6. Logout
        final logoutContext = MockRequestContext();
        when(() => logoutContext.read<User>()).thenReturn(authenticatedUser2);

        final logoutResponse = await authFrog.logout(logoutContext);
        expect(logoutResponse.statusCode, equals(HttpStatus.noContent));

        // 7. Try Refresh again (should fail as it was rotated and then logged out)
        final refreshResponse2 = await authFrog.refresh(refreshContext);
        expect(refreshResponse2.statusCode, equals(HttpStatus.unauthorized));

        // 8. Try Refresh with new token (should also fail because logout revoked the serial)
        final refreshContext3 = MockRequestContext();
        final refreshRequest3 = MockRequest();
        when(() => refreshContext3.request).thenReturn(refreshRequest3);
        when(
          () => refreshRequest3.headers,
        ).thenReturn({'content-length': '100'});
        when(
          () => refreshRequest3.json(),
        ).thenAnswer((_) async => {'refresh_token': newRefreshToken});

        final refreshResponse3 = await authFrog.refresh(refreshContext3);
        expect(refreshResponse3.statusCode, equals(HttpStatus.unauthorized));
      },
    );
  });
}
