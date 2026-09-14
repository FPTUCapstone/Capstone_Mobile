import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';

void main() {
  group('registration validators', () {
    test('accepts the backend password policy', () {
      expect(Validators.password('Password123!'), isNull);
    });

    test('rejects password whitespace at either edge like the Web form', () {
      expect(Validators.password(' Password123!'), isNotNull);
      expect(Validators.password('Password123! '), isNotNull);
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
