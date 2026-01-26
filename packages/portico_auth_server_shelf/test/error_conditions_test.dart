import 'dart:convert';

import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_server_shelf/portico_auth_server_shelf.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:jose_plus/jose.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class MockAuthTokensManager extends Mock implements AuthTokensManager {}

class MockAuthCredentialsManager extends Mock
    implements AuthCredentialsManager {}

class MockAuthRoleManager extends Mock implements AuthRoleManager {}

class MockJosePayload extends Mock implements JosePayload {}

void main() {
  late MockAuthTokensManager tokens;
  late MockAuthCredentialsManager credentials;
  late MockAuthRoleManager roles;
  late AuthShelf shelfService;

  setUp(() {
    tokens = MockAuthTokensManager();
    credentials = MockAuthCredentialsManager();
    roles = MockAuthRoleManager();
    shelfService = AuthShelf(tokens, credentials: credentials, roles: roles);
  });

  group('Error Conditions', () {
    group('register', () {
      test('returns 403 when password does not meet requirements', () async {
        when(
          () => credentials.registerUser(any(), any()),
        ).thenThrow(const InvalidCredentialsException('weak password'));

        final body = jsonEncode({
          'user_id': 'test@example.com',
          'password': 'weak',
        });
        final request = Request(
          'POST',
          Uri.parse('http://localhost/register'),
          headers: {
            'content-type': 'application/json',
            'content-length': '${body.length}',
          },
          body: body,
        );

        final response = await shelfService.register(request);
        expect(response.statusCode, 403);
        expect(
          response.readAsString(),
          completion(
            contains('user_id or password does not meet requirements'),
          ),
        );
      });

      test('returns 500 on unexpected error', () async {
        when(
          () => credentials.registerUser(any(), any()),
        ).thenThrow(Exception('database failure'));

        final body = jsonEncode({
          'user_id': 'test@example.com',
          'password': 'password',
        });
        final request = Request(
          'POST',
          Uri.parse('http://localhost/register'),
          headers: {
            'content-type': 'application/json',
            'content-length': '${body.length}',
          },
          body: body,
        );

        final response = await shelfService.register(request);
        expect(response.statusCode, 500);
      });
    });

    group('login', () {
      test('returns 500 on unexpected error', () async {
        when(
          () => credentials.verifyCredentials(any(), any()),
        ).thenThrow(Exception('something went wrong'));

        final body = jsonEncode({
          'user_id': 'test@example.com',
          'password': 'password',
        });
        final request = Request(
          'POST',
          Uri.parse('http://localhost/login'),
          headers: {
            'content-type': 'application/json',
            'content-length': '${body.length}',
          },
          body: body,
        );

        final response = await shelfService.login(request);
        expect(response.statusCode, 500);
      });
    });

    group('refresh (Refresh)', () {
      test('returns 401 when RefreshTokenInvalid is thrown', () async {
        when(
          () => tokens.getPayload(any(), isRefreshToken: true),
        ).thenThrow(const RefreshTokenInvalid('expired'));

        final body = jsonEncode({'refresh_token': 'bad_token'});
        final request = Request(
          'POST',
          Uri.parse('http://localhost/refresh'),
          headers: {
            'content-type': 'application/json',
            'content-length': '${body.length}',
          },
          body: body,
        );

        final response = await shelfService.refresh(request);
        expect(response.statusCode, 401);
        expect(response.readAsString(), completion(contains('expired')));
      });

      test('returns 400 on unexpected error', () async {
        when(
          () => tokens.getPayload(any(), isRefreshToken: true),
        ).thenThrow(Exception('boom'));

        final body = jsonEncode({'refresh_token': 'token'});
        final request = Request(
          'POST',
          Uri.parse('http://localhost/refresh'),
          headers: {
            'content-type': 'application/json',
            'content-length': '${body.length}',
          },
          body: body,
        );

        final response = await shelfService.refresh(request);
        expect(response.statusCode, 400);
      });
    });

    group('logout', () {
      test('returns 401 when RefreshTokenInvalid is thrown', () async {
        when(
          () => tokens.getPayload(any(), isRefreshToken: true),
        ).thenThrow(const RefreshTokenInvalid('invalid'));

        final body = jsonEncode({'refresh_token': 'bad_token'});
        final request = Request(
          'POST',
          Uri.parse('http://localhost/logout'),
          headers: {
            'content-type': 'application/json',
            'content-length': '${body.length}',
          },
          body: body,
        );

        final response = await shelfService.logout(request);
        expect(response.statusCode, 401);
      });

      test('returns 400 on unexpected error', () async {
        when(
          () => tokens.getPayload(any(), isRefreshToken: true),
        ).thenThrow(Exception('boom'));

        final body = jsonEncode({'refresh_token': 'token'});
        final request = Request(
          'POST',
          Uri.parse('http://localhost/logout'),
          headers: {
            'content-type': 'application/json',
            'content-length': '${body.length}',
          },
          body: body,
        );

        final response = await shelfService.logout(request);
        expect(response.statusCode, 400);
      });
    });

    group('middleware', () {
      test('returns 401 on unexpected error during check', () async {
        when(() => tokens.getPayload(any())).thenThrow(Exception('fail'));

        final handler = shelfService.middleware((req) => Response.ok(''));
        final request = Request(
          'GET',
          Uri.parse('http://localhost/protected'),
          headers: {'authorization': 'Bearer token'},
        );

        final response = await handler(request);
        expect(response.statusCode, 401);
      });
    });
  });
}
