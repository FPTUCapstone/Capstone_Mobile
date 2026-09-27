import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';

void main() {
  group('registration validators', () {
    test('accepts the backend password policy', () {
      expect(Validators.password('Password123!'), isNull);
    });

    test('rejects every supported whitespace character at either edge', () {
      final invalidPasswords = [
        ' Password1!',
        'Password1! ',
        '\tPassword1!',
        'Password1!\t',
        '\nPassword1!',
        'Password1!\n',
        '\u00A0Password1!',
        'Password1!\u00A0',
      ];

      for (final password in invalidPasswords) {
        expect(
          Validators.password(password),
          isNotNull,
          reason: 'Expected edge whitespace ${password.codeUnits} to fail.',
        );
      }
    });

    test('validates every password character class independently', () {
      expect(Validators.password('password1!'), isNotNull);
      expect(Validators.password('PASSWORD1!'), isNotNull);
      expect(Validators.password('Password!'), isNotNull);
      expect(Validators.password('Password1'), isNotNull);
      expect(Validators.password('Password1!'), isNull);
    });

    test('validates reset codes as exactly six ASCII digits', () {
      expect(Validators.otp('12345'), isNotNull);
      expect(Validators.otp('1234567'), isNotNull);
      expect(Validators.otp('12a456'), isNotNull);
      expect(Validators.otp('012345'), isNull);
    });

    test('rejects password values outside the backend length range', () {
      expect(Validators.password('Aa1!aaa'), isNotNull);
      expect(Validators.password('Aa1!${List.filled(68, 'a').join()}'), isNull);
      expect(
        Validators.password('Aa1!${List.filled(69, 'a').join()}'),
        isNotNull,
      );
    });

    test('allows nullable phone and validates provided phone values', () {
      expect(Validators.phone(null), isNull);
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('0912345678'), isNull);
      expect(Validators.phone('091234567'), isNotNull);
      expect(Validators.phone('09123456789'), isNotNull);
    });

    test('validates full name boundaries and Unicode letters', () {
      expect(Validators.fullName('Nguyen Van A'), isNull);
      expect(Validators.fullName('Nguyen Ánh'), isNull);
      expect(Validators.fullName('A'), isNotNull);
      expect(Validators.fullName(List.filled(151, 'A').join()), isNotNull);
      expect(Validators.fullName('   '), isNotNull);
    });
  });
}
