import 'dart:convert';
import 'dart:io';
import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_server_frog/portico_auth_server_frog.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockAuthTokensManager extends Mock implements AuthTokensManager {}

class MockAuthCredentialsManager extends Mock
    implements AuthCredentialsManager {}

class MockAuthRoleManager extends Mock implements AuthRoleManager {}

class MockRequestContext extends Mock implements RequestContext {}

class MockRequest extends Mock implements Request {}

void main() {
  group('AuthFrog.login', () {
    late AuthTokensManager tokens;
    late AuthCredentialsManager credentials;
    late AuthRoleManager roles;
    late RequestContext context;
    late Request request;
    late AuthFrog authFrog;

    setUp(() {
      tokens = MockAuthTokensManager();
      credentials = MockAuthCredentialsManager();
      roles = MockAuthRoleManager();
      context = MockRequestContext();
      request = MockRequest();
      authFrog = AuthFrog(
        tokens: tokens,
        credentials: credentials,
        roles: roles,
      );

      when(() => context.request).thenReturn(request);
    });

    test('returns 200 and tokens when credentials are valid', () async {
      const userId = 'test@example.com';
      const password = 'password123';
      final body = jsonEncode({'user_id': userId, 'password': password});

      when(
        () => request.headers,
      ).thenReturn({'content-length': '${body.length}'});
      when(() => request.json()).thenAnswer((_) async => jsonDecode(body));
      when(
        () => credentials.verifyCredentials(userId, password),
      ).thenAnswer((_) async => true);
      when(() => roles.getUserAssignments(userId)).thenAnswer(
        (_) async => [
          const RoleAssignment(
            userId: userId,
            roleName: 'admin',
            scope: 'global',
          ),
        ],
      );
      when(
        () => roles.listRoles(includeInactive: any(named: 'includeInactive')),
      ).thenAnswer(
        (_) async => [
          const Role(
            name: 'admin',
            displayName: 'Admin',
            description: 'Administrator',
          ),
        ],
      );

      final tokenSet = TokenSet(
        name: 'test',
        refreshToken: 'rt',
        accessToken: 'at',
        expirationDate: DateTime.parse('2026-01-01T00:00:00Z'),
      );

      when(
        () => tokens.mintTokens(userId, extraClaims: any(named: 'extraClaims')),
      ).thenAnswer((_) async => tokenSet);

      final response = await authFrog.login(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final responseBody = await response.json();
      expect(responseBody['access_token'], equals('at'));

      verify(() => credentials.verifyCredentials(userId, password)).called(1);
      verify(() => roles.getUserAssignments(userId)).called(1);
      verify(
        () => roles.listRoles(includeInactive: any(named: 'includeInactive')),
      ).called(1);
      verify(
        () => tokens.mintTokens(userId, extraClaims: any(named: 'extraClaims')),
      ).called(1);
    });

    test('returns 401 when credentials are invalid', () async {
      const userId = 'test@example.com';
      const password = 'wrong-password';
      final body = jsonEncode({'user_id': userId, 'password': password});

      when(
        () => request.headers,
      ).thenReturn({'content-length': '${body.length}'});
      when(() => request.json()).thenAnswer((_) async => jsonDecode(body));
      when(
        () => credentials.verifyCredentials(userId, password),
      ).thenThrow(const InvalidCredentialsException());

      final response = await authFrog.login(context);

      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test('returns 400 when body is missing username or password', () async {
      final body = jsonEncode({
        'user_id': 'test@example.com',
      }); // missing password

      when(
        () => request.headers,
      ).thenReturn({'content-length': '${body.length}'});
      when(() => request.json()).thenAnswer((_) async => jsonDecode(body));

      final response = await authFrog.login(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('returns 400 when body is not JSON', () async {
      when(() => request.headers).thenReturn({'content-length': '10'});
      when(() => request.json()).thenThrow(const FormatException());

      final response = await authFrog.login(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('returns 500 when unexpected error occurs', () async {
      when(() => request.headers).thenReturn({'content-length': '10'});
      when(() => request.json()).thenThrow(Exception('unexpected'));

      final response = await authFrog.login(context);

      expect(response.statusCode, equals(HttpStatus.internalServerError));
    });
  });
}
