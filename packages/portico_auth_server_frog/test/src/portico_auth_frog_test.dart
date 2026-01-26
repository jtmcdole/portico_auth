import 'dart:convert';

import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_server_frog/portico_auth_server_frog.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:jose_plus/jose.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAuthTokensManager extends Mock implements AuthTokensManager {}

class MockAuthTokensStorageAdapter extends Mock
    implements AuthTokensStorageAdapter {}

class MockAuthCredentialsManager extends Mock
    implements AuthCredentialsManager {}

class MockAuthRoleManager extends Mock implements AuthRoleManager {}

class MockRequestContext extends Mock implements RequestContext {}

class MockJosePayload extends Mock implements JosePayload {}

void main() {
  group('AuthFrog', () {
    late AuthTokensManager tokens;
    late MockAuthTokensStorageAdapter storage;
    late AuthCredentialsManager credentials;
    late AuthRoleManager roles;
    late RequestContext context;

    setUp(() {
      tokens = MockAuthTokensManager();
      storage = MockAuthTokensStorageAdapter();
      credentials = MockAuthCredentialsManager();
      roles = MockAuthRoleManager();
      context = MockRequestContext();

      when(() => tokens.storage).thenReturn(storage);
    });

    test('can be instantiated', () {
      expect(
        AuthFrog(tokens: tokens, credentials: credentials, roles: roles),
        isNotNull,
      );
    });

    group('authenticator', () {
      late AuthFrog authFrog;

      setUp(() {
        authFrog = AuthFrog(
          tokens: tokens,
          credentials: credentials,
          roles: roles,
        );
      });

      test('returns User when token is valid', () async {
        const token = 'valid-token';
        final payload = MockJosePayload();
        final jsonContent = """{
          "sub": "test-user-id",
          "roles": [
            {"role": "admin", "scope": "global"}
          ],
          "iat": 1234567890,
          "exp": 1234567899
        }""";

        when(() => payload.jsonContent).thenReturn(jsonDecode(jsonContent));
        when(() => tokens.getPayload(token)).thenAnswer((_) async => payload);

        final user = await authFrog.authenticator(context, token);

        expect(user, isNotNull);
        expect(user!.id, equals('test-user-id'));
        expect(
          user.roles,
          contains(const UserRole(role: 'admin', scope: 'global')),
        );
      });

      /* 
      // Revocation check is currently disabled in AuthFrog to match Shelf implementation
      // and avoid DB lookups on every request.
      test('returns null when token serial is invalidated', () async {
        const token = 'revoked-token';
        const serial = 'revoked-serial';
        const userId = 'test-user-id';

        final payload = MockJosePayload();
        final jsonContent = {
          'sub': userId,
          'serial': serial,
          'roles': <dynamic>[],
          'iat': 1234567890,
          'exp': 1234567899,
        };

        when(() => payload.jsonContent).thenReturn(jsonContent);
        when(() => tokens.getPayload(token)).thenAnswer((_) async => payload);
        when(
          () => storage.getRefreshTokenCounter(
            serial: serial,
            userId: userId,
          ),
        ).thenAnswer((_) async => []);

        final user = await authFrog.authenticator(context, token);
        expect(user, isNull);
      });
      */

      test('returns null when token is expired', () async {
        const token = 'expired-token';
        when(
          () => tokens.getPayload(token),
        ).thenThrow(const AccessTokenInvalid('expired'));

        final user = await authFrog.authenticator(context, token);
        expect(user, isNull);
      });

      test('returns null when token is malformed', () async {
        const token = 'malformed-token';
        when(
          () => tokens.getPayload(token),
        ).thenThrow(const AccessTokenInvalid('malformed'));

        final user = await authFrog.authenticator(context, token);
        expect(user, isNull);
      });

      test('returns null when manager throws unexpected error', () async {
        const token = 'some-token';
        when(
          () => tokens.getPayload(token),
        ).thenThrow(Exception('database down'));

        final user = await authFrog.authenticator(context, token);
        expect(user, isNull);
      });
    });
  });
}
