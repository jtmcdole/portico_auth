import 'dart:convert';
import 'dart:io';
import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_server_frog/portico_auth_server_frog.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:jose_plus/jose.dart';
import 'package:test/test.dart';

class MockAuthTokensManager extends Mock implements AuthTokensManager {}

class MockAuthRoleManager extends Mock implements AuthRoleManager {}

class MockRequestContext extends Mock implements RequestContext {}

class MockRequest extends Mock implements Request {}

class MockJosePayload extends Mock implements JosePayload {}

class MockAuthCredentialsStorageAdapter extends Mock
    implements AuthCredentialsStorageAdapter {}

void main() {
  group('AuthFrog.refresh', () {
    late AuthTokensManager tokens;
    late AuthCredentialsManager credentials;
    late MockAuthCredentialsStorageAdapter storage;
    late AuthRoleManager roles;
    late RequestContext context;
    late Request request;
    late AuthFrog authFrog;

    setUp(() {
      tokens = MockAuthTokensManager();
      storage = MockAuthCredentialsStorageAdapter();
      credentials = AuthCredentialsManager(storage: storage);
      roles = MockAuthRoleManager();
      context = MockRequestContext();
      request = MockRequest();
      authFrog = AuthFrog(
        tokens: tokens,
        credentials: credentials,
        roles: roles,
      );

      when(() => context.request).thenReturn(request);

      // Setup default mock for headers to avoid null errors if checked
      when(() => request.headers).thenReturn({'content-length': '10'});

      // Default mock for createUser and others if needed
      when(
        () => storage.createUser(
          userId: any(named: 'userId'),
          salt: any(named: 'salt'),
          hash: any(named: 'hash'),
          creationTime: any(named: 'creationTime'),
        ),
      ).thenAnswer((_) async {});
    });

    test('returns 200 and new tokens when refresh token is valid', () async {
      const refreshToken = 'valid-refresh-token';
      const username = 'test@example.com';
      final body = jsonEncode({'refresh_token': refreshToken});

      when(() => request.json()).thenAnswer((_) async => jsonDecode(body));

      final payload = MockJosePayload();
      when(() => payload.jsonContent).thenReturn({'sub': username});
      when(
        () => tokens.getPayload(refreshToken, isRefreshToken: true),
      ).thenAnswer((_) async => payload);

      when(
        () => storage.getPasswordHash(username),
      ).thenAnswer((_) async => (hash: 'h', salt: 's'));

      when(
        () => roles.getUserAssignments(username),
      ).thenAnswer((_) async => []);
      when(
        () => roles.listRoles(includeInactive: any(named: 'includeInactive')),
      ).thenAnswer((_) async => []);

      final tokenSet = TokenSet(
        accessToken: 'new-at',
        refreshToken: 'new-rt',
        expirationDate: DateTime.parse('2026-01-01T01:00:00Z'),
        name: 'test',
      );

      when(
        () => tokens.newAccessToken(
          refreshToken,
          extraClaims: any(named: 'extraClaims'),
        ),
      ).thenAnswer((_) async => tokenSet);

      final response = await authFrog.refresh(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final responseBody = await response.json();
      expect(responseBody['access_token'], equals('new-at'));
      expect(responseBody['refresh_token'], equals('new-rt'));

      verify(
        () => tokens.newAccessToken(
          refreshToken,
          extraClaims: any(named: 'extraClaims'),
        ),
      ).called(1);
    });

    test(
      'returns 200 and new tokens with updated roles when roles have changed',
      () async {
        const refreshToken = 'valid-refresh-token';
        const username = 'test@example.com';
        final body = jsonEncode({'refresh_token': refreshToken});

        when(() => request.json()).thenAnswer((_) async => jsonDecode(body));

        final payload = MockJosePayload();
        when(() => payload.jsonContent).thenReturn({'sub': username});
        when(
          () => tokens.getPayload(refreshToken, isRefreshToken: true),
        ).thenAnswer((_) async => payload);

        when(
          () => storage.getPasswordHash(username),
        ).thenAnswer((_) async => (hash: 'h', salt: 's'));

        final assignments = [
          const RoleAssignment(
            userId: username,
            roleName: 'admin',
            scope: 'global',
          ),
        ];
        final activeRoles = [
          const Role(name: 'admin', displayName: 'Admin', description: 'Admin'),
        ];

        when(
          () => roles.getUserAssignments(username),
        ).thenAnswer((_) async => assignments);
        when(
          () => roles.listRoles(includeInactive: any(named: 'includeInactive')),
        ).thenAnswer((_) async => activeRoles);

        final expectedRoles = [
          {'role': 'admin', 'scope': 'global'},
        ];

        final tokenSet = TokenSet(
          accessToken: 'new-at',
          refreshToken: 'new-rt',
          expirationDate: DateTime.parse('2026-01-01T01:00:00Z'),
          name: 'test',
        );

        when(
          () => tokens.newAccessToken(
            refreshToken,
            extraClaims: {'roles': expectedRoles},
          ),
        ).thenAnswer((_) async => tokenSet);

        final response = await authFrog.refresh(context);

        expect(response.statusCode, equals(HttpStatus.ok));
        final responseBody = await response.json();
        expect(responseBody['access_token'], equals('new-at'));

        verify(
          () => tokens.newAccessToken(
            refreshToken,
            extraClaims: {'roles': expectedRoles},
          ),
        ).called(1);
      },
    );

    test('returns 401 when user no longer exists', () async {
      const refreshToken = 'valid-token';
      const username = 'deleted@example.com';
      final body = jsonEncode({'refresh_token': refreshToken});

      when(() => request.json()).thenAnswer((_) async => jsonDecode(body));

      final payload = MockJosePayload();
      when(() => payload.jsonContent).thenReturn({'sub': username});
      when(
        () => tokens.getPayload(refreshToken, isRefreshToken: true),
      ).thenAnswer((_) async => payload);

      when(
        () => storage.getPasswordHash(username),
      ).thenThrow(UserDoesNotExistException(username));

      final response = await authFrog.refresh(context);

      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test('returns 401 when refresh token is invalid', () async {
      const refreshToken = 'invalid-token';
      final body = jsonEncode({'refresh_token': refreshToken});

      when(() => request.json()).thenAnswer((_) async => jsonDecode(body));
      when(
        () => tokens.getPayload(refreshToken, isRefreshToken: true),
      ).thenThrow(const RefreshTokenInvalid('invalid'));

      final response = await authFrog.refresh(context);

      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test('returns 401 when refresh token is a replay attack', () async {
      const refreshToken = 'reused-token';
      final body = jsonEncode({'refresh_token': refreshToken});

      when(() => request.json()).thenAnswer((_) async => jsonDecode(body));
      when(
        () => tokens.getPayload(refreshToken, isRefreshToken: true),
      ).thenThrow(const RefreshTokenInvalid('potential replay attack'));

      final response = await authFrog.refresh(context);

      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test('returns 400 when body is missing refresh_token', () async {
      final body = jsonEncode({'something': 'else'});

      when(() => request.json()).thenAnswer((_) async => jsonDecode(body));

      final response = await authFrog.refresh(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('returns 400 when body is not JSON', () async {
      when(() => request.json()).thenThrow(const FormatException());

      final response = await authFrog.refresh(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('returns 500 when unexpected error occurs', () async {
      when(() => request.json()).thenThrow(Exception('unexpected'));

      final response = await authFrog.refresh(context);

      expect(response.statusCode, equals(HttpStatus.internalServerError));
    });
  });
}
