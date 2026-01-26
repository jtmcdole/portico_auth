import 'package:portico_auth_client/src/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('AuthException', () {
    test('AuthInvalidCredentialsException has default message', () {
      const exception = AuthInvalidCredentialsException();
      expect(exception.message, contains('Invalid username or password'));
      expect(exception.toString(), contains('AuthInvalidCredentialsException'));
    });

    test('AuthNetworkException has default message', () {
      const exception = AuthNetworkException();
      expect(exception.message, contains('network error'));
    });

    test('AuthServerException stores status code', () {
      const exception = AuthServerException('Server error', statusCode: 500);
      expect(exception.message, equals('Server error'));
      expect(exception.statusCode, equals(500));
    });

    test('AuthUserAlreadyExistsException has default message', () {
      const exception = AuthUserAlreadyExistsException();
      expect(
        exception.message,
        contains('user with this identifier already exists'),
      );
    });

    test('AuthNotAuthenticatedException has default message', () {
      const exception = AuthNotAuthenticatedException();
      expect(exception.message, contains('User is not authenticated'));
    });
  });
}
