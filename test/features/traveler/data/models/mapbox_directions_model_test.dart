import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/mapbox_directions_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';

Map<String, dynamic> _step(
  String type,
  String? modifier,
  List<double> location, {
  String instruction = 'Go',
}) => {
  'distance': 120.5,
  'maneuver': {
    'type': type,
    'modifier': ?modifier,
    'instruction': instruction,
    'location': location,
  },
};

void main() {
  group('MapboxDirectionsModel', () {
    test('parses geometry in GeoJSON order and maps maneuvers', () {
      final route = MapboxDirectionsModel.fromJson({
        'code': 'Ok',
        'routes': [
          {
            'distance': 1500.0,
            'duration': 300,
            'geometry': {
              'type': 'LineString',
              'coordinates': [
                [108.2, 16.0],
                [108.21, 16.01],
              ],
            },
            'legs': [
              {
                'steps': [
                  _step('depart', null, [108.2, 16.0]),
                  _step('turn', 'left', [
                    108.205,
                    16.005,
                  ], instruction: 'Turn left onto Bạch Đằng'),
                  _step('turn', 'sharp right', [108.207, 16.007]),
                  _step('continue', 'uturn', [108.208, 16.008]),
                  _step('arrive', null, [108.21, 16.01]),
                ],
              },
            ],
          },
        ],
      });

      expect(
        route.geometry.first,
        const NavigationCoordinate(latitude: 16.0, longitude: 108.2),
      );
      expect(route.distanceMeters, 1500);
      expect(route.durationSeconds, 300);
      expect(route.steps.map((step) => step.direction), [
        ManeuverDirection.straight,
        ManeuverDirection.turnLeft,
        ManeuverDirection.turnRight,
        ManeuverDirection.uTurn,
        ManeuverDirection.arrive,
      ]);
      expect(route.steps[1].instruction, 'Turn left onto Bạch Đằng');
      expect(route.steps[1].location.latitude, 16.005);
    });

    test('treats a non-Ok response as no route', () {
      expect(
        () => MapboxDirectionsModel.fromJson({'code': 'NoRoute', 'routes': []}),
        throwsFormatException,
      );
    });
  });
}
