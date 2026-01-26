import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_server_frog/src/portico_auth_frog.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:test/test.dart';

class MockAuthTokensManager extends Mock implements AuthTokensManager {}

class MockAuthCredentialsManager extends Mock
    implements AuthCredentialsManager {}

class MockAuthRoleManager extends Mock implements AuthRoleManager {}

class MockRequestContext extends Mock implements RequestContext {}

class MockRequest extends Mock implements Request {}

class MockAuthTokensStorageAdapter extends Mock
    implements AuthTokensStorageAdapter {}

void main() {
  group('AuthFrog Content-Length Checks', () {
    late MockAuthTokensManager tokens;
    late MockAuthCredentialsManager credentials;
    late MockAuthRoleManager roles;
    late MockAuthTokensStorageAdapter tokenStorage;
    late AuthFrog authFrog;
    late MockRequestContext context;
    late MockRequest request;

    setUp(() {
      tokens = MockAuthTokensManager();
      credentials = MockAuthCredentialsManager();
      roles = MockAuthRoleManager();
      tokenStorage = MockAuthTokensStorageAdapter();

      when(() => tokens.storage).thenReturn(tokenStorage);

      authFrog = AuthFrog(
        tokens: tokens,
        credentials: credentials,
        roles: roles,
      );
      context = MockRequestContext();
      request = MockRequest();
      when(() => context.request).thenReturn(request);
    });

    // Helper to simulate a request with a specific content-length
    void setUpRequestWithLength(int length) {
      when(() => request.headers).thenReturn({'content-length': '$length'});
      // Mock json() to avoid null pointer if code proceeds (though we expect it to fail before)
      when(() => request.json()).thenAnswer((_) async => <String, dynamic>{});
    }

    void setUpRequestWithoutLength() {
      when(() => request.headers).thenReturn({});
    }

    group('login', () {
      test('returns BadRequest when Content-Length is missing', () async {
        setUpRequestWithoutLength();
        final response = await authFrog.login(context);
        expect(response.statusCode, HttpStatus.badRequest);
      });

      test('returns BadRequest when Content-Length > 10KB', () async {
        setUpRequestWithLength(10241);
        final response = await authFrog.login(context);
        expect(response.statusCode, HttpStatus.badRequest);
      });

      test('proceeds when Content-Length is valid', () async {
        setUpRequestWithLength(100);
        // We expect it to try to read json, which we mocked to return empty map
        // The implementation checks for userId/password presence next
        final response = await authFrog.login(context);
        // It should fail validation of userId/password, but NOT be the content-length error
        // If content-length check passed, it reads json. Our mock returns empty map.
        // Then it checks userId/pass. They are null.
        // It logs 'Login failed: Missing userId or password' and returns BadRequest.
        // So we still get BadRequest, but for a different reason.
        // To verify it passed the size check, we can verify request.json() was called.
        verify(() => request.json()).called(1);
        expect(response.statusCode, HttpStatus.badRequest);
      });
    });

    group('register', () {
      test('returns BadRequest when Content-Length is missing', () async {
        setUpRequestWithoutLength();
        final response = await authFrog.register(context);
        expect(response.statusCode, HttpStatus.badRequest);
      });

      test('returns BadRequest when Content-Length > 10KB', () async {
        setUpRequestWithLength(10241);
        final response = await authFrog.register(context);
        expect(response.statusCode, HttpStatus.badRequest);
      });

      test('proceeds when Content-Length is valid', () async {
        setUpRequestWithLength(100);
        final response = await authFrog.register(context);
        verify(() => request.json()).called(1);
        expect(response.statusCode, HttpStatus.badRequest);
      });
    });

    group('refresh', () {
      test('returns BadRequest when Content-Length is missing', () async {
        setUpRequestWithoutLength();
        final response = await authFrog.refresh(context);
        expect(response.statusCode, HttpStatus.badRequest);
      });

      test('returns BadRequest when Content-Length > 10KB', () async {
        setUpRequestWithLength(10241);
        final response = await authFrog.refresh(context);
        expect(response.statusCode, HttpStatus.badRequest);
      });

      test('proceeds when Content-Length is valid', () async {
        setUpRequestWithLength(100);
        final response = await authFrog.refresh(context);
        verify(() => request.json()).called(1);
        expect(response.statusCode, HttpStatus.badRequest);
      });
    });
  });
}
