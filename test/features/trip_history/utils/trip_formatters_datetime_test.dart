import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';

void main() {
  group('formatVietnamDateTime', () {
    test('shows dd/MM/yyyy HH:mm in UTC+7 on a 24-hour clock', () {
      expect(
        TripFormatters.formatVietnamDateTime(DateTime.utc(2026, 10, 20, 17)),
        '21/10/2026 00:00',
      );
      expect(
        TripFormatters.formatVietnamDateTime(DateTime.utc(2026, 10, 1, 2, 5)),
        '01/10/2026 09:05',
      );
      expect(
        TripFormatters.formatVietnamDateTime(DateTime.utc(2026, 10, 1, 16, 59)),
        '01/10/2026 23:59',
      );
    });

    test('treats a local DateTime by its instant, not its wall clock', () {
      final instant = DateTime.utc(2026, 10, 1, 2, 5);

      expect(
        TripFormatters.formatVietnamDateTime(instant.toLocal()),
        '01/10/2026 09:05',
      );
    });
  });

  group('formatVietnamTime', () {
    test('shows HH:mm in UTC+7', () {
      expect(
        TripFormatters.formatVietnamTime(DateTime.utc(2026, 10, 1, 2, 5)),
        '09:05',
      );
      expect(
        TripFormatters.formatVietnamTime(DateTime.utc(2026, 10, 1, 17)),
        '00:00',
      );
    });
  });
}
