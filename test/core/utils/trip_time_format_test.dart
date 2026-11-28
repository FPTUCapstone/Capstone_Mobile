import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';

void main() {
  // Thursday 2026-10-15 18:42 in Vietnam (UTC+7).
  final start = DateTime.utc(2026, 10, 15, 11, 42);

  test('a same-day trip shows one date and a time range', () {
    expect(
      tripSchedule(start, start.add(const Duration(hours: 3, minutes: 45))),
      'T5, 15/10 · 18:42–22:27',
    );
  });

  test('a trip crossing midnight shows both dates', () {
    expect(
      tripSchedule(start, start.add(const Duration(hours: 8))),
      'T5, 15/10 18:42 – T6, 16/10 02:42',
    );
  });

  test('times are Vietnam wall clock whatever the device zone', () {
    expect(tripClock(DateTime.utc(2026, 10, 15, 17, 30)), '00:30');
    expect(tripDate(DateTime.utc(2026, 10, 15, 17, 30)), 'T6, 16/10');
  });

  test('a time on a later day than the trip start carries its date', () {
    final nextMorning = DateTime.utc(2026, 10, 16, 1);

    expect(tripTimeLabel(start, tripStart: start), '18:42');
    expect(tripTimeLabel(nextMorning, tripStart: start), 'T6, 16/10 08:00');
  });

  test('durations read naturally up to several days', () {
    expect(tripDuration(45), '45 phút');
    expect(tripDuration(135), '2 giờ 15 phút');
    expect(tripDuration(26 * 60), '1 ngày 2 giờ');
    expect(tripDuration(72 * 60), '3 ngày');
  });
}
