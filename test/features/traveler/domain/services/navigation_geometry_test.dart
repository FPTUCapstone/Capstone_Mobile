import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/arrival_detector.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/geo_distance.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/route_progress_tracker.dart';

const _origin = NavigationCoordinate(latitude: 16.0, longitude: 108.2);

/// ~111 m per 0.001° of latitude.
NavigationCoordinate _north(double meters) => NavigationCoordinate(
  latitude: _origin.latitude + meters / 111195,
  longitude: _origin.longitude,
);

NavigationSessionItem _item(int id, NavigationCoordinate at) =>
    NavigationSessionItem(
      itemId: id,
      sequenceNo: id,
      poiId: id,
      poiName: 'Stop $id',
      latitude: at.latitude,
      longitude: at.longitude,
      plannedArrival: DateTime.utc(2026, 10, 20, 2),
      plannedDeparture: DateTime.utc(2026, 10, 20, 3),
      isMandatory: false,
      status: NavigationItemStatus.pending,
      reachedAt: null,
      skippedAt: null,
    );

NavigationPosition _at(NavigationCoordinate coordinate, int seconds) =>
    NavigationPosition(
      coordinate: coordinate,
      timestamp: DateTime.utc(2026, 10, 20, 2).add(Duration(seconds: seconds)),
    );

void main() {
  group('distanceMeters', () {
    test('matches the haversine distance for a short hop', () {
      expect(distanceMeters(_origin, _north(500)), closeTo(500, 1));
    });
  });

  group('ArrivalDetector', () {
    final stop = _item(1, _north(1000));

    test('requires the dwell time inside the radius', () {
      final detector = ArrivalDetector(dwell: const Duration(seconds: 20));
      final inside = _north(980);

      expect(
        detector.update(position: _at(inside, 0), candidates: [stop]),
        isNull,
      );
      expect(
        detector.update(position: _at(inside, 10), candidates: [stop]),
        isNull,
      );
      expect(detector.update(position: _at(inside, 20), candidates: [stop]), 1);
    });

    test('restarts the dwell when the Traveler leaves the radius', () {
      final detector = ArrivalDetector(dwell: const Duration(seconds: 20));

      detector.update(position: _at(_north(990), 0), candidates: [stop]);
      detector.update(position: _at(_north(800), 10), candidates: [stop]);
      expect(
        detector.update(position: _at(_north(990), 25), candidates: [stop]),
        isNull,
      );
      expect(
        detector.update(position: _at(_north(990), 45), candidates: [stop]),
        1,
      );
    });

    test('a suppressed stop is proposed again only after leaving the area', () {
      final detector = ArrivalDetector(dwell: Duration.zero);

      expect(
        detector.update(position: _at(_north(1000), 0), candidates: [stop]),
        1,
      );
      detector.suppress(1);
      expect(
        detector.update(position: _at(_north(1000), 5), candidates: [stop]),
        isNull,
      );
      // 60 m away: outside the radius but within 1.5x, still suppressed.
      detector.update(position: _at(_north(940), 10), candidates: [stop]);
      expect(
        detector.update(position: _at(_north(1000), 15), candidates: [stop]),
        isNull,
      );
      // 200 m away releases the suppression.
      detector.update(position: _at(_north(800), 20), candidates: [stop]);
      expect(
        detector.update(position: _at(_north(1000), 25), candidates: [stop]),
        1,
      );
    });

    test('picks the nearest satisfied stop', () {
      final detector = ArrivalDetector(dwell: Duration.zero);
      final near = _item(2, _north(1010));

      expect(
        detector.update(
          position: _at(_north(1012), 0),
          candidates: [stop, near],
        ),
        2,
      );
    });
  });

  group('RouteProgressTracker', () {
    final route = NavigationRoute(
      geometry: [_origin, _north(500), _north(1000)],
      distanceMeters: 1000,
      durationSeconds: 200,
      steps: [
        NavigationStep(
          instruction: 'Head north',
          direction: ManeuverDirection.straight,
          location: _origin,
          distanceMeters: 500,
        ),
        NavigationStep(
          instruction: 'Continue',
          direction: ManeuverDirection.straight,
          location: _north(500),
          distanceMeters: 500,
        ),
        NavigationStep(
          instruction: 'Arrive',
          direction: ManeuverDirection.arrive,
          location: _north(1000),
          distanceMeters: 0,
        ),
      ],
    );

    test('reports remaining distance, time, and the upcoming maneuver', () {
      final progress = RouteProgressTracker(route).progress(_north(200));

      expect(progress.distanceFromRouteMeters, lessThan(1));
      expect(progress.remainingDistanceMeters, closeTo(800, 2));
      expect(progress.remainingDurationSeconds, closeTo(160, 1));
      expect(progress.nextStep?.instruction, 'Continue');
      expect(progress.distanceToNextStepMeters, closeTo(300, 2));

      final later = RouteProgressTracker(route).progress(_north(700));
      expect(later.nextStep?.direction, ManeuverDirection.arrive);
      expect(later.distanceToNextStepMeters, closeTo(300, 2));
    });

    test('measures how far the Traveler is from the line', () {
      const offRoute = NavigationCoordinate(
        latitude: 16.002,
        longitude: 108.201,
      );

      final progress = RouteProgressTracker(route).progress(offRoute);

      expect(progress.distanceFromRouteMeters, closeTo(107, 3));
    });
  });
}
