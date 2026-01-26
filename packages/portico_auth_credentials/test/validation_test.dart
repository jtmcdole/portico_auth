import 'package:portico_auth_credentials/portico_auth_credentials.dart';
import 'package:test/test.dart';

void main() {
  group('AuthValidation', () {
    test('specialsRegex matches all required special characters', () {
      const allSpecials = r'''~`!@#$%^&*()_+-=[]\{}|;':",./<>?''';

      for (var i = 0; i < allSpecials.length; i++) {
        final char = allSpecials[i];
        expect(
          AuthValidation.specialsRegex.hasMatch(char),
          isTrue,
          reason: 'Character "$char" should be matched by specialsRegex',
        );
      }

      expect(
        AuthValidation.specialsRegex.allMatches(allSpecials),
        hasLength(32),
      );
    });

    test('validatePasswordRigid requires special character', () {
      // Missing special character
      expect(
        () => AuthValidation.validatePasswordRigid('Abcdefg1'),
        throwsA(isA<InvalidCredentialsException>()),
      );

      // Has special character from the new set
      expect(AuthValidation.validatePasswordRigid('Abcdefg1-'), isTrue);
      expect(AuthValidation.validatePasswordRigid('Abcdefg1='), isTrue);
    });

    test('validateUsername works', () {
      expect(AuthValidation.validateUsername('joebob'), isTrue);
      expect(
        () => AuthValidation.validateUsername('jo'),
        throwsA(isA<InvalidCredentialsException>()),
      );
    });
  });
}
