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
  group('AuthFrog.register', () {
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

    test('returns 200 and user view when registration is successful', () async {
      const userId = 'newuser@example.com';
      const password = 'Password123!';
      final body = jsonEncode({'user_id': userId, 'password': password});

      when(
        () => request.headers,
      ).thenReturn({'content-length': '${body.length}'});
      when(() => request.json()).thenAnswer((_) async => jsonDecode(body));
      when(
        () => credentials.registerUser(userId, password),
      ).thenAnswer((_) async {});
      when(() => roles.getUserAssignments(userId)).thenAnswer((_) async => []);

      when(
        () => roles.listRoles(includeInactive: any(named: 'includeInactive')),
      ).thenAnswer((_) async => []);

      final response = await authFrog.register(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      final responseBody = await response.json();
      expect(responseBody, containsPair('id', userId));
      expect(responseBody, containsPair('roles', isEmpty));

      verify(() => credentials.registerUser(userId, password)).called(1);
    });

    test('returns 409 when user already exists', () async {
      const userId = 'existing@example.com';
      const password = 'Password123!';
      final body = jsonEncode({'user_id': userId, 'password': password});

      when(
        () => request.headers,
      ).thenReturn({'content-length': '${body.length}'});
      when(() => request.json()).thenAnswer((_) async => jsonDecode(body));
      when(
        () => credentials.registerUser(userId, password),
      ).thenThrow(UserAlreadyExistsException(userId));

      final response = await authFrog.register(context);

      expect(response.statusCode, equals(HttpStatus.conflict));
    });

    test('returns 400 when body is missing username or password', () async {
      final body = jsonEncode({
        'user_id': 'test@example.com',
      }); // missing password

      when(
        () => request.headers,
      ).thenReturn({'content-length': '${body.length}'});
      when(() => request.json()).thenAnswer((_) async => jsonDecode(body));

      final response = await authFrog.register(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('returns 400 when password is weak', () async {
      const userId = 'test@example.com';
      const password = 'weak';
      final body = jsonEncode({'user_id': userId, 'password': password});

      when(
        () => request.headers,
      ).thenReturn({'content-length': '${body.length}'});
      when(() => request.json()).thenAnswer((_) async => jsonDecode(body));
      when(
        () => credentials.registerUser(userId, password),
      ).thenThrow(const InvalidCredentialsException('invalid password'));

      final response = await authFrog.register(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('returns 400 when body is not JSON', () async {
      when(() => request.headers).thenReturn({'content-length': '10'});
      when(() => request.json()).thenThrow(const FormatException());

      final response = await authFrog.register(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('returns 500 when unexpected error occurs', () async {
      when(() => request.headers).thenReturn({'content-length': '10'});
      when(() => request.json()).thenThrow(Exception('unexpected'));

      final response = await authFrog.register(context);

      expect(response.statusCode, equals(HttpStatus.internalServerError));
    });
  });
}
