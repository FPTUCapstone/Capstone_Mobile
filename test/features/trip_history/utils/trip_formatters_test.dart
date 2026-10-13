import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';

void main() {
  group('TripFormatters Unit Tests', () {
    test('formatVietnamDate: formats dd/MM/yyyy in UTC+7', () {
      final utcTime = DateTime.utc(2026, 10, 8, 5, 0, 0); // 12:00 in UTC+7
      expect(TripFormatters.formatVietnamDate(utcTime), equals('08/10/2026'));

      final leapYear = DateTime.utc(2024, 2, 29, 3, 0, 0);
      expect(TripFormatters.formatVietnamDate(leapYear), equals('29/02/2024'));
    });

    test(
      'toVietnamCalendarDay: normalizes timestamps to Vietnam calendar day at UTC 00:00:00',
      () {
        final morning = DateTime.utc(2026, 10, 8, 1, 0, 0); // 08:00 VN
        final evening = DateTime.utc(2026, 10, 8, 16, 59, 59); // 23:59:59 VN
        final nextDay = DateTime.utc(
          2026,
          10,
          8,
          17,
          0,
          1,
        ); // 00:00:01 on Oct 9 VN

        final morningDay = TripFormatters.toVietnamCalendarDay(morning);
        final eveningDay = TripFormatters.toVietnamCalendarDay(evening);
        final nextDayNormalized = TripFormatters.toVietnamCalendarDay(nextDay);

        expect(morningDay, equals(DateTime.utc(2026, 10, 8)));
        expect(eveningDay, equals(DateTime.utc(2026, 10, 8)));
        expect(morningDay, equals(eveningDay));

        expect(nextDayNormalized, equals(DateTime.utc(2026, 10, 9)));
        expect(nextDayNormalized.isAfter(morningDay), isTrue);
      },
    );

    test(
      'toVietnamCalendarDay: boundary hours in UTC+7 (00:00, 06:59, 10:00, 23:59, midnight rollover)',
      () {
        // 00:00:00 VN time is 17:00:00 UTC previous day
        final midnightVn = DateTime.utc(2026, 10, 7, 17, 0, 0);
        expect(
          TripFormatters.toVietnamCalendarDay(midnightVn),
          equals(DateTime.utc(2026, 10, 8)),
        );

        // 06:59:59 VN time is 23:59:59 UTC previous day
        final earlyMorningVn = DateTime.utc(2026, 10, 7, 23, 59, 59);
        expect(
          TripFormatters.toVietnamCalendarDay(earlyMorningVn),
          equals(DateTime.utc(2026, 10, 8)),
        );

        // 10:00:00 VN time is 03:00:00 UTC same day
        final morningVn = DateTime.utc(2026, 10, 8, 3, 0, 0);
        expect(
          TripFormatters.toVietnamCalendarDay(morningVn),
          equals(DateTime.utc(2026, 10, 8)),
        );

        // 23:59:59 VN time is 16:59:59 UTC same day
        final lateNightVn = DateTime.utc(2026, 10, 8, 16, 59, 59);
        expect(
          TripFormatters.toVietnamCalendarDay(lateNightVn),
          equals(DateTime.utc(2026, 10, 8)),
        );

        // Exactly next-day 00:00:00 VN time is 17:00:00 UTC same day
        final nextDayVn = DateTime.utc(2026, 10, 8, 17, 0, 0);
        expect(
          TripFormatters.toVietnamCalendarDay(nextDayVn),
          equals(DateTime.utc(2026, 10, 9)),
        );
      },
    );

    test(
      'toCivilCalendarDay: preserves civil calendar date across local timezones without shifting',
      () {
        // A date selected from date picker has year, month, day components
        final civilLocal = DateTime(2026, 10, 8, 0, 0, 0);
        final civilUtc = DateTime.utc(2026, 10, 8, 0, 0, 0);
        final civilLate = DateTime(2026, 10, 8, 23, 45, 0);

        expect(
          TripFormatters.toCivilCalendarDay(civilLocal),
          equals(DateTime.utc(2026, 10, 8)),
        );
        expect(
          TripFormatters.toCivilCalendarDay(civilUtc),
          equals(DateTime.utc(2026, 10, 8)),
        );
        expect(
          TripFormatters.toCivilCalendarDay(civilLate),
          equals(DateTime.utc(2026, 10, 8)),
        );
      },
    );

    test('toVietnamCalendarDay: handles month and year rollovers', () {
      final endOfYear = DateTime.utc(2025, 12, 31, 10, 0, 0);
      final newYear = DateTime.utc(2026, 1, 1, 0, 0, 0);

      final endOfYearDay = TripFormatters.toVietnamCalendarDay(endOfYear);
      final newYearDay = TripFormatters.toVietnamCalendarDay(newYear);

      expect(endOfYearDay, equals(DateTime.utc(2025, 12, 31)));
      expect(newYearDay, equals(DateTime.utc(2026, 1, 1)));
      expect(endOfYearDay.isBefore(newYearDay), isTrue);
    });

    test(
      'formatVnd: formats numbers with thousands separators and handles zero as Free',
      () {
        expect(
          TripFormatters.formatVnd(0),
          equals(TripHistoryStringsEn.labelFree),
        );
        expect(TripFormatters.formatVnd(1000), equals('1,000 VND'));
        expect(TripFormatters.formatVnd(2400000), equals('2,400,000 VND'));
      },
    );
  });
}
