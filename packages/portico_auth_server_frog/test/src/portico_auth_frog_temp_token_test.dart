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
  group('AuthFrog.generateTempToken', () {
    late MockAuthTokensManager tokens;
    late MockAuthCredentialsManager credentials;
    late MockAuthRoleManager roles;
    late MockRequestContext context;
    late MockRequest request;
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

    test('returns 200 and temp token when request is authorized', () async {
      const accessToken = 'valid-access-token';
      const tempToken = 'new-temp-token';

      final user = User(id: 'test-user', roles: [], metadata: {});
      when(() => context.read<User>()).thenReturn(user);
      when(
        () => request.headers,
      ).thenReturn({'authorization': 'Bearer $accessToken'});

      when(
        () => tokens.generateTempToken(accessToken),
      ).thenAnswer((_) async => tempToken);

      final response = await authFrog.generateTempToken(context);

      expect(response.statusCode, equals(HttpStatus.ok));
      expect(await response.body(), equals(tempToken));
      expect(response.headers['Content-Type'], equals('application/jwt'));

      verify(() => tokens.generateTempToken(accessToken)).called(1);
    });

    test('returns 400 when authorization header is missing', () async {
      final user = User(id: 'test-user', roles: [], metadata: {});
      when(() => context.read<User>()).thenReturn(user);
      when(() => request.headers).thenReturn({});

      final response = await authFrog.generateTempToken(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('returns 400 when authorization header is malformed', () async {
      final user = User(id: 'test-user', roles: [], metadata: {});
      when(() => context.read<User>()).thenReturn(user);
      when(
        () => request.headers,
      ).thenReturn({'authorization': 'Basic something'});

      final response = await authFrog.generateTempToken(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });

    test('returns 400 when manager throws exception', () async {
      const accessToken = 'valid-access-token';

      final user = User(id: 'test-user', roles: [], metadata: {});
      when(() => context.read<User>()).thenReturn(user);
      when(
        () => request.headers,
      ).thenReturn({'authorization': 'Bearer $accessToken'});

      when(
        () => tokens.generateTempToken(accessToken),
      ).thenThrow(Exception('failed'));

      final response = await authFrog.generateTempToken(context);

      expect(response.statusCode, equals(HttpStatus.badRequest));
    });
  });
}
