import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/utils/qr_invitation_parser.dart';

void main() {
  group('QrInvitationParser', () {
    test('parses valid deep link URI and returns uppercase code', () {
      final result = QrInvitationParser.parse(
        'tripmate://groups/join?code=a7k4p2qx',
      );
      expect(result, 'A7K4P2QX');
    });

    test('parses direct 8-character code and returns uppercase code', () {
      final result = QrInvitationParser.parse('hoian8kp');
      expect(result, 'HOIAN8KP');
    });

    test('trims whitespace around code or URI', () {
      final result = QrInvitationParser.parse('  A7K4P2QX  ');
      expect(result, 'A7K4P2QX');

      final uriResult = QrInvitationParser.parse(
        '  tripmate://groups/join?code=HOIAN8KP  ',
      );
      expect(uriResult, 'HOIAN8KP');
    });

    test('returns null for empty or whitespace-only input', () {
      expect(QrInvitationParser.parse(null), isNull);
      expect(QrInvitationParser.parse(''), isNull);
      expect(QrInvitationParser.parse('   '), isNull);
    });

    test('returns null for wrong scheme or path', () {
      expect(
        QrInvitationParser.parse('https://example.com?code=A7K4P2QX'),
        isNull,
      );
      expect(
        QrInvitationParser.parse('tripmate://other/path?code=A7K4P2QX'),
        isNull,
      );
    });

    test('returns null when code is not 8 alphanumeric characters', () {
      expect(QrInvitationParser.parse('SHORT'), isNull);
      expect(QrInvitationParser.parse('TOOLONGCODE'), isNull);
      expect(QrInvitationParser.parse('CODE-123'), isNull);
      expect(
        QrInvitationParser.parse('tripmate://groups/join?code=INVALID!'),
        isNull,
      );
    });
  });
}
