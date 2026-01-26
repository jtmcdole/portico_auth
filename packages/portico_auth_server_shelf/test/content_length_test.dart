import 'package:mocktail/mocktail.dart';
import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:portico_auth_roles/portico_auth_roles.dart';
import 'package:portico_auth_server_shelf/portico_auth_server_shelf.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class MockAuthTokensManager extends Mock implements AuthTokensManager {}

class MockAuthCredentialsManager extends Mock
    implements AuthCredentialsManager {}

class MockAuthRoleManager extends Mock implements AuthRoleManager {}

class MockAuthTokensStorageAdapter extends Mock
    implements AuthTokensStorageAdapter {}

void main() {
  group('AuthShelf Content-Length Checks', () {
    late MockAuthTokensManager tokens;
    late MockAuthCredentialsManager credentials;
    late MockAuthRoleManager roles;
    late MockAuthTokensStorageAdapter tokenStorage;
    late AuthShelf authShelf;

    setUp(() {
      tokens = MockAuthTokensManager();
      credentials = MockAuthCredentialsManager();
      roles = MockAuthRoleManager();
      tokenStorage = MockAuthTokensStorageAdapter();

      when(() => tokens.storage).thenReturn(tokenStorage);

      authShelf = AuthShelf(tokens, credentials: credentials, roles: roles);
    });

    Request makeRequestWithHeader(
      String method,
      Uri url,
      String? contentLengthHeader,
    ) {
      return Request(
        method,
        url,
        headers: {
          if (contentLengthHeader != null)
            'content-length': contentLengthHeader,
          'content-type': 'application/json',
        },
      );
    }

    Request makeRequestMissingLength(String method, Uri url) {
      return Request(
        method,
        url,
        headers: {'content-type': 'application/json'},
        body: Stream<List<int>>.fromIterable(
          [],
        ), // Empty stream prevents inference
      );
    }

    group('login', () {
      final url = Uri.parse('http://localhost/login');

      test('returns BadRequest when Content-Length is missing', () async {
        final request = makeRequestMissingLength('POST', url);
        final response = await authShelf.login(request);
        expect(response.statusCode, 400);
        expect(await response.readAsString(), 'Invalid payload size');
      });

      test('returns BadRequest when Content-Length > 10KB', () async {
        final request = makeRequestWithHeader('POST', url, '10241');
        final response = await authShelf.login(request);
        expect(response.statusCode, 400);
        expect(await response.readAsString(), 'Invalid payload size');
      });

      test('proceeds (fails on body) when Content-Length is valid', () async {
        // We provide a valid content length but empty body, so it will fail on JSON decode or missing fields
        // But NOT "Invalid payload size"
        final request = Request(
          'POST',
          url,
          headers: {'content-length': '2', 'content-type': 'application/json'},
          body: '{}',
        );
        final response = await authShelf.login(request);

        final body = await response.readAsString();
        // It should fail on "Missing userId or password" because body is empty json object
        expect(body, isNot('Invalid payload size'));
        expect(response.statusCode, 400);
      });
    });

    group('register', () {
      final url = Uri.parse('http://localhost/register');

      test('returns BadRequest when Content-Length is missing', () async {
        final request = makeRequestMissingLength('POST', url);
        final response = await authShelf.register(request);
        expect(response.statusCode, 400);
        expect(await response.readAsString(), 'Invalid payload size');
      });

      test('returns BadRequest when Content-Length > 10KB', () async {
        final request = makeRequestWithHeader('POST', url, '10241');
        final response = await authShelf.register(request);
        expect(response.statusCode, 400);
        expect(await response.readAsString(), 'Invalid payload size');
      });
    });

    group('refresh', () {
      final url = Uri.parse('http://localhost/token');

      test('returns BadRequest when Content-Length is missing', () async {
        final request = makeRequestMissingLength('POST', url);
        final response = await authShelf.refresh(request);
        expect(response.statusCode, 400);
        // This handler might return "Bad Request" first if content-type check passes?
        // Wait, content-length check is after content-type check.
        // Let's ensure content-type is set.
        // It returns "Invalid payload size" if content-length check fails.
        expect(await response.readAsString(), 'Invalid payload size');
      });

      test('returns BadRequest when Content-Length > 10KB', () async {
        final request = makeRequestWithHeader('POST', url, '10241');
        final response = await authShelf.refresh(request);
        expect(response.statusCode, 400);
        expect(await response.readAsString(), 'Invalid payload size');
      });
    });

    group('logout', () {
      final url = Uri.parse('http://localhost/invalidate');

      test('returns BadRequest when Content-Length is missing', () async {
        final request = makeRequestMissingLength('POST', url);
        final response = await authShelf.logout(request);
        expect(response.statusCode, 400);
        expect(await response.readAsString(), 'Invalid payload size');
      });

      test('returns BadRequest when Content-Length > 10KB', () async {
        final request = makeRequestWithHeader('POST', url, '10241');
        final response = await authShelf.logout(request);
        expect(response.statusCode, 400);
        expect(await response.readAsString(), 'Invalid payload size');
      });
    });
  });
}
