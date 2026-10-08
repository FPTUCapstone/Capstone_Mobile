import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_waypoint.dart';

void main() {
  group('ActiveTripWaypoint copyWith', () {
    final originalWaypoint = ActiveTripWaypoint(
      id: 1,
      name: 'Prime Meridian Stop',
      orderIndex: 0,
      plannedArrival: DateTime.utc(2026, 10, 20, 8),
      stayDurationMinutes: 45,
      latitude: 51.4769,
      longitude: 108.2640, // Non-zero longitude
      isReached: false,
    );

    test(
      'FIX 5: copyWith(longitude: 0.0) correctly assigns 0.0 when previous is non-zero',
      () {
        final updated = originalWaypoint.copyWith(longitude: 0.0);
        expect(updated.longitude, 0.0);
        expect(updated.latitude, originalWaypoint.latitude);
        expect(updated.name, originalWaypoint.name);
      },
    );

    test('copyWith() keeps previous longitude when parameter is omitted', () {
      final updated = originalWaypoint.copyWith(name: 'Updated Name');
      expect(updated.longitude, 108.2640);
      expect(updated.name, 'Updated Name');
    });

    test(
      'copyWith(latitude: 0.0) correctly assigns 0.0 when previous is non-zero',
      () {
        final updated = originalWaypoint.copyWith(latitude: 0.0);
        expect(updated.latitude, 0.0);
        expect(updated.longitude, originalWaypoint.longitude);
      },
    );

    test('copyWith() keeps previous latitude when parameter is omitted', () {
      final updated = originalWaypoint.copyWith(isReached: true);
      expect(updated.latitude, 51.4769);
      expect(updated.isReached, isTrue);
    });
  });
}
