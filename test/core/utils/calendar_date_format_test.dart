import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/utils/calendar_date_format.dart';

void main() {
  test('calendar dates have padded day/month and a four-digit year', () {
    expect(formatCalendarDate(DateTime(2026, 1, 2)), '02/01/2026');
    expect(formatCalendarDate(DateTime.utc(2026, 12, 31)), '31/12/2026');
  });

  test(
    'date-only fields retain their calendar day without timezone conversion',
    () {
      expect(
        formatCalendarDate(DateTime.utc(2026, 1, 2, 23, 59)),
        '02/01/2026',
      );
      expect(
        formatCalendarDateTime(DateTime(2026, 1, 2, 3, 4)),
        '02/01/2026 03:04:00.000',
      );
      expect(
        formatCalendarDateTime(DateTime.utc(2026, 1, 2, 3, 4, 5, 6, 7)),
        '02/01/2026 03:04:05.006007Z',
      );
    },
  );
}
