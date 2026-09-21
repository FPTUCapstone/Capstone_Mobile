import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';

void main() {
  group('AvailabilityStatus', () {
    test('fromString returns correct enum for valid strings', () {
      expect(
        AvailabilityStatus.fromString('available'),
        AvailabilityStatus.available,
      );
      expect(
        AvailabilityStatus.fromString('soldOut'),
        AvailabilityStatus.soldOut,
      );
      expect(
        AvailabilityStatus.fromString('noUpcomingSchedule'),
        AvailabilityStatus.noUpcomingSchedule,
      );
      expect(
        AvailabilityStatus.fromString('unknown'),
        AvailabilityStatus.unknown,
      );
    });

    test('fromString returns unknown for invalid strings', () {
      expect(AvailabilityStatus.fromString('foo'), AvailabilityStatus.unknown);
      expect(AvailabilityStatus.fromString(''), AvailabilityStatus.unknown);
    });
  });
}
