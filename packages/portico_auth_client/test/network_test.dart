import 'dart:convert';
import 'package:portico_auth_client/src/exceptions.dart';
import 'package:portico_auth_client/src/network.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  group('AuthNetworkClient', () {
    late MockHttpClient httpClient;
    late AuthNetworkClient networkClient;
    final baseUrl = Uri.parse('http://localhost:8080');

    setUp(() {
      httpClient = MockHttpClient();
      networkClient = AuthNetworkClient(
        httpClient,
        loginUrl: baseUrl.resolve('/login'),
        registerUrl: baseUrl.resolve('/register'),
        refreshUrl: baseUrl.resolve('/refresh'),
        logoutUrl: baseUrl.resolve('/logout'),
        updatePasswordUrl: baseUrl.resolve('/updatePassword'),
      );
    });

    test('login returns token map on success', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'access_token': 'at', 'refresh_token': 'rt'}),
          200,
        ),
      );

      final result = await networkClient.login('test@test.com', 'pass');

      expect(result['access_token'], equals('at'));
      expect(result['refresh_token'], equals('rt'));

      verify(
        () => httpClient.post(
          baseUrl.replace(path: '/login'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'user_id': 'test@test.com', 'password': 'pass'}),
        ),
      ).called(1);
    });

    test('login throws AuthInvalidCredentialsException on 401', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('Unauthorized', 401));

      expect(
        () => networkClient.login('test@test.com', 'pass'),
        throwsA(isA<AuthInvalidCredentialsException>()),
      );
    });

    test('register throws AuthUserAlreadyExistsException on 409', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('Conflict', 409));

      expect(
        () => networkClient.register('test@test.com', 'pass'),
        throwsA(isA<AuthUserAlreadyExistsException>()),
      );
    });

    test('refresh returns new tokens', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(jsonEncode({'access_token': 'new_at'}), 200),
      );

      final result = await networkClient.refresh('old_rt');
      expect(result['access_token'], equals('new_at'));
    });

    test('generic 500 error throws AuthServerException', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

      expect(
        () => networkClient.refresh('rt'),
        throwsA(
          isA<AuthServerException>().having(
            (e) => e.statusCode,
            'statusCode',
            500,
          ),
        ),
      );
    });

    test('logout attempts to release tokens', () {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => throw "best effort");
      expect(networkClient.logout('1234'), completes);
      verify(
        () => httpClient.post(
          baseUrl.replace(path: '/logout'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'refresh_token': '1234'}),
        ),
      ).called(1);
    });

    test('updatePassword sends correct body and headers', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 200));

      final headers = {'Authorization': 'Bearer token'};
      await networkClient.updatePassword(
        'old-pass',
        'new-pass',
        headers: headers,
      );

      verify(
        () => httpClient.post(
          baseUrl.resolve('/updatePassword'),
          headers: {...headers, 'content-type': 'application/json'},
          body: jsonEncode({
            'old_password': 'old-pass',
            'new_password': 'new-pass',
          }),
        ),
      ).called(1);
    });

    test('closes internally allocated client', () {
      networkClient = AuthNetworkClient(
        httpClient,
        loginUrl: baseUrl.resolve('login'),
        registerUrl: baseUrl.resolve('register'),
        refreshUrl: baseUrl.resolve('refresh'),
        logoutUrl: baseUrl.resolve('logout'),
        updatePasswordUrl: baseUrl.resolve('/updatePassword'),
        needsClosing: true,
      );
      networkClient.close();
      verify(() => httpClient.close()).called(1);
    });
  });
}
