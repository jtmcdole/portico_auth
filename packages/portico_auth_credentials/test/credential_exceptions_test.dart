import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:test/test.dart';

void main() {
  group('Exceptions', () {
    test('UserAlreadyExistsException.toString() contains userId', () {
      final userId = 'taken@example.com';
      final exception = UserAlreadyExistsException(userId);
      expect(exception.toString(), contains(userId));
      expect(exception.toString(), contains('$UserAlreadyExistsException'));
    });

    test('UserDoesNotExistException.toString() contains userId', () {
      final userId = 'missing@example.com';
      final exception = UserDoesNotExistException(userId);
      expect(exception.toString(), contains(userId));
      expect(exception.toString(), contains('$UserDoesNotExistException'));
    });

    test('InvalidCredentialsException.toString()', () {
      const exception = InvalidCredentialsException();
      expect(exception.toString(), contains('$InvalidCredentialsException'));
      expect(exception.toString(), contains('Invalid userId or password'));
    });
  });
}
