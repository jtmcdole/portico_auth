import 'dart:convert';
import 'package:portico_auth_client/portico_auth_client.dart';
import 'package:portico_auth_client/src/network.dart';
import 'package:portico_auth_tokens/portico_auth_tokens.dart';
import 'package:clock/clock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockNetworkClient extends Mock implements AuthNetworkClient {}

void main() {
  group('AuthClient', () {
    late InMemoryTokenStorage storage;
    late MockNetworkClient mockNetwork;
    late AuthClient authClient;

    final tokenSet = TokenSet(
      name: 'Test User',
      accessToken: 'access.token.jwt',
      refreshToken: 'refresh.token.jwe',
      expirationDate: DateTime.now().add(const Duration(hours: 1)),
    );

    // Helper to generate a dummy JWT
    String generateJwt({
      required DateTime expires,
      Map<String, dynamic> roles = const {},
    }) {
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'none'})));
      final payload = base64Url.encode(
        utf8.encode(
          jsonEncode({
            'sub': 'user@example.com',
            'name': 'Test User',
            'exp': expires.millisecondsSinceEpoch ~/ 1000,
            ...roles,
          }),
        ),
      );
      return '$header.$payload.signature';
    }

    setUp(() {
      storage = InMemoryTokenStorage();
      mockNetwork = MockNetworkClient();

      registerFallbackValue(tokenSet);
      when(() => mockNetwork.logout(any())).thenAnswer((_) async {});

      authClient = AuthClient(
        loginUrl: Uri.parse('http://localhost/login'),
        registerUrl: Uri.parse('http://localhost/register'),
        refreshUrl: Uri.parse('http://localhost/refresh'),
        logoutUrl: Uri.parse('http://localhost/logout'),
        storage: storage,
        networkClient: mockNetwork,
      );
    });

    tearDown(() {
      authClient.close();
    });

    test('initial state is Unauthenticated', () {
      expect(authClient.state, isA<Unauthenticated>());
    });

    test(
      'initializes with Unauthenticated if storage load fails or token invalid',
      () async {
        storage.save(
          TokenSet(
            name: 'test',
            accessToken: 'invalid.jwt',
            refreshToken: 'rt',
            expirationDate: DateTime(2020),
          ),
        );

        final newClient = AuthClient(
          loginUrl: Uri.parse('http://localhost/login'),
          registerUrl: Uri.parse('http://localhost/register'),
          refreshUrl: Uri.parse('http://localhost/refresh'),
          logoutUrl: Uri.parse('http://localhost/logout'),
          storage: storage,
          networkClient: mockNetwork,
        );
        await newClient.ready;

        expect(newClient.state, isA<Unauthenticated>());
        newClient.close();
      },
    );

    group('login', () {
      test('updates state and saves tokens on success', () async {
        final mockJwt = generateJwt(
          expires: DateTime.now().add(const Duration(hours: 1)),
          roles: {
            'roles': [
              {'role': 'admin', 'scope': 'global'},
            ],
          },
        );

        when(() => mockNetwork.login(any(), any())).thenAnswer(
          (_) async => TokenSet(
            accessToken: mockJwt,
            refreshToken: 'refresh',
            expirationDate: DateTime.now().add(const Duration(hours: 1)),
            name: 'Test User',
          ).toJson(),
        );

        await authClient.login('user', 'pass');

        final loadedTokens = await storage.load();
        expect(loadedTokens?.accessToken, equals(mockJwt));
        expect(authClient.state, isA<Authenticated>());
        final user = (authClient.state as Authenticated).user;
        expect(user.id, 'user@example.com');
        expect(user.roles.first.role, 'admin');
        expect(user.roles.first.scope, 'global');
      });

      test('handles missing roles in token', () async {
        final mockJwt = generateJwt(
          expires: DateTime.now().add(const Duration(hours: 1)),
        );

        when(() => mockNetwork.login(any(), any())).thenAnswer(
          (_) async => TokenSet(
            accessToken: mockJwt,
            refreshToken: 'rt',
            expirationDate: DateTime.now().add(const Duration(hours: 1)),
            name: 'Name',
          ).toJson(),
        );

        await authClient.login('u', 'p');
        expect((authClient.state as Authenticated).user.roles, isEmpty);
      });

      test('throws AuthUnknownException if token payload is invalid', () async {
        final mockJwt =
            'header.${base64Url.encode(utf8.encode(jsonEncode({})))}.signature';
        when(() => mockNetwork.login(any(), any())).thenAnswer(
          (_) async => TokenSet(
            accessToken: mockJwt,
            refreshToken: 'rt',
            expirationDate: DateTime.now().add(const Duration(hours: 1)),
            name: 'Name',
          ).toJson(),
        );

        expect(
          () => authClient.login('u', 'p'),
          throwsA(isA<AuthUnknownException>()),
        );
      });

      test('throws FormatException if token format is invalid', () async {
        when(() => mockNetwork.login(any(), any())).thenAnswer(
          (_) async => TokenSet(
            accessToken: 'invalid-token',
            refreshToken: 'rt',
            expirationDate: DateTime.now().add(const Duration(hours: 1)),
            name: 'Name',
          ).toJson(),
        );

        expect(
          () => authClient.login('u', 'p'),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('logout', () {
      test('clears tokens and updates state', () async {
        storage.save(tokenSet);
        await authClient.logout();
        expect(await storage.load(), isNull);
        expect(authClient.state, isA<Unauthenticated>());
      });
    });

    group('register', () {
      test('calls network register', () async {
        when(() => mockNetwork.register(any(), any())).thenAnswer((_) async {});
        await authClient.register('user', 'pass');
        verify(() => mockNetwork.register('user', 'pass')).called(1);
      });
    });

    group('httpHeaders', () {
      test('returns authorization header when authenticated', () async {
        final mockJwt = generateJwt(
          expires: DateTime.now().add(const Duration(hours: 1)),
        );
        storage.save(
          TokenSet(
            name: 'Test',
            accessToken: mockJwt,
            refreshToken: 'refresh',
            expirationDate: DateTime.now().add(const Duration(hours: 1)),
          ),
        );

        final newClient = AuthClient(
          loginUrl: Uri.parse('http://localhost/login'),
          registerUrl: Uri.parse('http://localhost/register'),
          refreshUrl: Uri.parse('http://localhost/refresh'),
          logoutUrl: Uri.parse('http://localhost/logout'),
          storage: storage,
          networkClient: mockNetwork,
        );

        final headers = await newClient.httpHeaders();
        expect(headers['Authorization'], 'Bearer $mockJwt');
        newClient.close();
      });

      test('throws when unauthenticated', () async {
        expect(
          () => authClient.httpHeaders(),
          throwsA(isA<AuthNotAuthenticatedException>()),
        );
      });

      test('refreshes token when near expiration', () async {
        return withClock(Clock.fixed(DateTime(2025, 1, 1, 12, 0, 0)), () async {
          final expires = DateTime(2025, 1, 1, 12, 2, 0);
          final oldJwt = generateJwt(expires: expires);
          storage.save(
            TokenSet(
              name: 'Test',
              accessToken: oldJwt,
              refreshToken: 'refresh',
              expirationDate: expires,
            ),
          );

          final newClient = AuthClient(
            loginUrl: Uri.parse('http://localhost/login'),
            registerUrl: Uri.parse('http://localhost/register'),
            refreshUrl: Uri.parse('http://localhost/refresh'),
            logoutUrl: Uri.parse('http://localhost/logout'),
            storage: storage,
            networkClient: mockNetwork,
            clock: Clock.fixed(DateTime(2025, 1, 1, 12, 0, 0)),
          );

          final newExpires = DateTime(2025, 1, 1, 13, 0, 0);
          final newJwt = generateJwt(expires: newExpires);
          when(() => mockNetwork.refresh('refresh')).thenAnswer(
            (_) async => TokenSet(
              accessToken: newJwt,
              refreshToken: 'new_refresh',
              expirationDate: newExpires,
              name: 'Test User',
            ).toJson(),
          );

          final headers = await newClient.httpHeaders();
          expect(headers['Authorization'], 'Bearer $newJwt');
          newClient.close();
        });
      });

      test('logs out if refresh fails and token is expired', () async {
        return withClock(Clock.fixed(DateTime(2025, 1, 1, 12, 0, 0)), () async {
          final expires = DateTime(2025, 1, 1, 11, 59, 0);
          final oldJwt = generateJwt(expires: expires);
          storage.save(
            TokenSet(
              name: 'Test',
              accessToken: oldJwt,
              refreshToken: 'refresh',
              expirationDate: expires,
            ),
          );

          final newClient = AuthClient(
            loginUrl: Uri.parse('http://localhost/login'),
            registerUrl: Uri.parse('http://localhost/register'),
            refreshUrl: Uri.parse('http://localhost/refresh'),
            logoutUrl: Uri.parse('http://localhost/logout'),
            storage: storage,
            networkClient: mockNetwork,
            clock: Clock.fixed(DateTime(2025, 1, 1, 12, 0, 0)),
          );

          when(
            () => mockNetwork.refresh('refresh'),
          ).thenThrow(const AuthInvalidCredentialsException());
          await expectLater(
            newClient.httpHeaders(),
            throwsA(isA<AuthNotAuthenticatedException>()),
          );
          expect(await storage.load(), isNull);
          newClient.close();
        });
      });

      test(
        'propagates error if refresh fails with generic error and token is expired',
        () async {
          return withClock(
            Clock.fixed(DateTime(2025, 1, 1, 12, 0, 0)),
            () async {
              final expires = DateTime(2025, 1, 1, 11, 59, 0);
              final oldJwt = generateJwt(expires: expires);
              storage.save(
                TokenSet(
                  name: 'Test',
                  accessToken: oldJwt,
                  refreshToken: 'refresh',
                  expirationDate: expires,
                ),
              );

              final newClient = AuthClient(
                loginUrl: Uri.parse('http://localhost/login'),
                registerUrl: Uri.parse('http://localhost/register'),
                refreshUrl: Uri.parse('http://localhost/refresh'),
                logoutUrl: Uri.parse('http://localhost/logout'),
                storage: storage,
                networkClient: mockNetwork,
                clock: Clock.fixed(DateTime(2025, 1, 1, 12, 0, 0)),
              );

              when(
                () => mockNetwork.refresh('refresh'),
              ).thenThrow(Exception('Network error'));

              await expectLater(
                newClient.httpHeaders(),
                throwsA(isA<Exception>()),
              );
              // User should still be logged in (tokens preserved)
              expect(await storage.load(), isNotNull);
              newClient.close();
            },
          );
        },
      );
    });

    group('Models and Exceptions', () {
      test('UserRole equality and hashCode', () {
        const r1 = UserRole(role: 'admin', scope: 's');
        const r2 = UserRole(role: 'admin', scope: 's');
        const r3 = UserRole(role: 'user');
        expect(r1, r2);
        expect(r1.hashCode, r2.hashCode);
        expect(r1, isNot(r3));
        expect(r1.toString(), 'admin:s');
        expect(r3.toString(), 'user');
      });

      test('AuthUser equality and hashCode', () {
        final u1 = AuthUser(id: '1', roles: []);
        final u2 = AuthUser(id: '1', roles: []);
        expect(u1, u2);
        expect(u1.hashCode, u2.hashCode);
      });

      test('AuthUnknownException', () {
        const e = AuthUnknownException('msg');
        expect(e.message, 'msg');
        expect(e.toString(), contains('AuthUnknownException'));
      });

      test('Authenticated equality and hashCode', () {
        final u1 = AuthUser(id: '1', roles: []);
        final s1 = Authenticated(u1);
        final s2 = Authenticated(u1);
        expect(s1, s2);
        expect(s1.hashCode, u1.hashCode);
      });
    });
  });
}
