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

void main() {
  group('AuthFrog.logout', () {
    late AuthTokensManager tokens;
    late AuthCredentialsManager credentials;
    late AuthRoleManager roles;
    late RequestContext context;
    late AuthFrog authFrog;

    setUp(() {
      tokens = MockAuthTokensManager();
      credentials = MockAuthCredentialsManager();
      roles = MockAuthRoleManager();
      context = MockRequestContext();
      authFrog = AuthFrog(
        tokens: tokens,
        credentials: credentials,
        roles: roles,
      );
    });

    test('returns 204 when logout is successful', () async {
      final user = User(
        id: 'test-user-id',
        roles: [],
        metadata: {'serial': 's123'},
      );

      when(() => context.read<User>()).thenReturn(user);
      when(
        () => tokens.invalidateRefreshToken('s123', 'test-user-id', any()),
      ).thenAnswer((_) async {});

      final response = await authFrog.logout(context);

      expect(response.statusCode, equals(HttpStatus.noContent));
      verify(
        () => tokens.invalidateRefreshToken('s123', 'test-user-id', any()),
      ).called(1);
    });

    test('returns 401 when user is not authenticated', () async {
      when(
        () => context.read<User>(),
      ).thenThrow(Exception('User not found in context'));

      final response = await authFrog.logout(context);

      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });

    test('returns 401 when token serial is missing', () async {
      final user = User(
        id: 'test@example.com',
        roles: [],
        metadata: {}, // Missing serial
      );

      when(() => context.read<User>()).thenReturn(user);

      final response = await authFrog.logout(context);

      expect(response.statusCode, equals(HttpStatus.unauthorized));
    });
  });
}
