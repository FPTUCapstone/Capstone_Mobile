import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';

/// Parses a Mapbox Directions API v5 response requested with
/// `geometries=geojson&steps=true&overview=full`.
abstract final class MapboxDirectionsModel {
  static NavigationRoute fromJson(Map<String, dynamic> json) {
    final routes = json['routes'];
    if (json['code'] != 'Ok' || routes is! List || routes.isEmpty) {
      throw const FormatException('No route available.');
    }
    final route = routes.first;
    if (route is! Map<String, dynamic>) {
      throw const FormatException('Invalid route.');
    }
    final geometry = route['geometry'];
    final legs = route['legs'];
    if (geometry is! Map ||
        geometry['coordinates'] is! List ||
        route['distance'] is! num ||
        route['duration'] is! num ||
        legs is! List) {
      throw const FormatException('Invalid route.');
    }

    return NavigationRoute(
      geometry: (geometry['coordinates'] as List)
          .map(_coordinate)
          .toList(growable: false),
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
      steps: [
        for (final leg in legs)
          if (leg is Map && leg['steps'] is List)
            for (final step in leg['steps'] as List) _step(step),
      ],
    );
  }

  static NavigationStep _step(Object? json) {
    if (json is! Map || json['maneuver'] is! Map) {
      throw const FormatException('Invalid route step.');
    }
    final maneuver = json['maneuver'] as Map;
    final type = maneuver['type'];
    final modifier = maneuver['modifier'];
    return NavigationStep(
      instruction: maneuver['instruction'] is String
          ? maneuver['instruction'] as String
          : '',
      direction: _direction(
        type is String ? type : '',
        modifier is String ? modifier : '',
      ),
      location: _coordinate(maneuver['location']),
      distanceMeters: json['distance'] is num
          ? (json['distance'] as num).toDouble()
          : 0,
    );
  }

  static ManeuverDirection _direction(String type, String modifier) {
    if (type == 'arrive') return ManeuverDirection.arrive;
    if (modifier == 'uturn') return ManeuverDirection.uTurn;
    if (modifier.contains('left')) return ManeuverDirection.turnLeft;
    if (modifier.contains('right')) return ManeuverDirection.turnRight;
    return ManeuverDirection.straight;
  }

  /// GeoJSON order is `[longitude, latitude]`.
  static NavigationCoordinate _coordinate(Object? json) {
    if (json is! List ||
        json.length < 2 ||
        json[0] is! num ||
        json[1] is! num) {
      throw const FormatException('Invalid route coordinate.');
    }
    return NavigationCoordinate(
      latitude: (json[1] as num).toDouble(),
      longitude: (json[0] as num).toDouble(),
    );
  }
}
