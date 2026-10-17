import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_cancellation_rule.dart';
import 'package:trip_mate_mobile/features/tour_detail/presentation/formatters/tour_detail_formatters.dart';

TourCancellationRule _rule(int days, double fee) =>
    TourCancellationRule(daysBeforeDeparture: days, feePercent: fee);

void main() {
  group('Vietnam time', () {
    test('an evening UTC time is already the next day in Vietnam', () {
      final value = DateTime.utc(2026, 11, 5, 17);

      expect(formatVietnamDate(value), '06/11/2026');
      expect(formatVietnamDateTime(value), '06/11/2026 00:00');
    });

    test('the boundary is exactly 17:00 UTC', () {
      expect(
        formatVietnamDateTime(DateTime.utc(2026, 12, 31, 16, 59)),
        '31/12/2026 23:59',
      );
      expect(
        formatVietnamDateTime(DateTime.utc(2026, 12, 31, 17)),
        '01/01/2027 00:00',
      );
    });

    test('does not depend on whether the input is flagged UTC', () {
      final utc = DateTime.utc(2026, 11, 6, 1);
      final offset = DateTime.parse('2026-11-06T08:00:00+07:00');

      expect(formatVietnamDateTime(utc), '06/11/2026 08:00');
      expect(formatVietnamDateTime(offset), '06/11/2026 08:00');
    });

    test('a same-day window shows the date once', () {
      expect(
        formatDepartureWindow(
          DateTime.utc(2026, 11, 6, 1),
          DateTime.utc(2026, 11, 6, 10),
        ),
        '06/11/2026 08:00 – 17:00',
      );
    });

    test('a multi-day window shows both dates', () {
      expect(
        formatDepartureWindow(
          DateTime.utc(2026, 11, 6, 1),
          DateTime.utc(2026, 11, 8, 10),
        ),
        '06/11/2026 08:00 – 08/11/2026 17:00',
      );
    });

    test('a window that crosses midnight only in Vietnam shows both dates', () {
      expect(
        formatDepartureWindow(
          DateTime.utc(2026, 11, 6, 15),
          DateTime.utc(2026, 11, 6, 18),
        ),
        '06/11/2026 22:00 – 07/11/2026 01:00',
      );
    });

    test('a window without an end shows only the start', () {
      expect(
        formatDepartureWindow(DateTime.utc(2026, 11, 6, 1), null),
        '06/11/2026 08:00',
      );
    });
  });

  group('formatVnd', () {
    test('groups thousands', () {
      expect(formatVnd(0), '0 VND');
      expect(formatVnd(900), '900 VND');
      expect(formatVnd(2890000), '2,890,000 VND');
      expect(formatVnd(1000), '1,000 VND');
    });
  });

  group('describeCancellationRules', () {
    test('describes the standard template as notice ranges', () {
      expect(
        describeCancellationRules([
          _rule(30, 0),
          _rule(15, 25),
          _rule(7, 50),
          _rule(0, 100),
        ]),
        [
          'Cancel 30 or more days before departure: free of charge',
          'Cancel 15 to 29 days before departure: 25% fee',
          'Cancel 7 to 14 days before departure: 50% fee',
          'Cancel less than 7 days before departure: 100% fee',
        ],
      );
    });

    test('sorts rules by notice regardless of input order', () {
      final lines = describeCancellationRules([_rule(0, 100), _rule(30, 0)]);

      expect(lines, [
        'Cancel 30 or more days before departure: free of charge',
        'Cancel less than 30 days before departure: 100% fee',
      ]);
    });

    test('a single rule at zero days applies at any time', () {
      expect(describeCancellationRules([_rule(0, 100)]), [
        'Cancel at any time: 100% fee',
      ]);
    });

    test('uses singular wording and exact days for adjacent rules', () {
      expect(describeCancellationRules([_rule(2, 0), _rule(1, 50)]), [
        'Cancel 2 or more days before departure: free of charge',
        'Cancel exactly 1 day before departure: 50% fee',
      ]);
    });

    test('keeps fractional percentages and trims trailing zeros', () {
      expect(describeCancellationRules([_rule(5, 12.5), _rule(0, 100)]), [
        'Cancel 5 or more days before departure: 12.5% fee',
        'Cancel less than 5 days before departure: 100% fee',
      ]);
    });

    test('no rules, no lines', () {
      expect(describeCancellationRules(const []), isEmpty);
    });
  });
}
