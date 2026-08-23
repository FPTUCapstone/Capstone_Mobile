import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts a normal email address', () {
      expect(Validators.email('traveler@tripmate.example'), isNull);
    });

    test('returns a safe validation message for malformed input', () {
      expect(Validators.email('not-an-email'), 'Enter a valid email address.');
    });
  });
}
