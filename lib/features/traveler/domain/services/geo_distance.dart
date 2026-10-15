import 'dart:math' as math;

import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';

const _earthRadiusMeters = 6371000.0;

/// Great-circle distance in meters.
double distanceMeters(NavigationCoordinate a, NavigationCoordinate b) {
  final lat1 = _radians(a.latitude);
  final lat2 = _radians(b.latitude);
  final dLat = lat2 - lat1;
  final dLng = _radians(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
}

/// Projection of a point onto segment [a, b] using a local equirectangular
/// approximation, accurate enough for street-scale navigation.
({double distanceMeters, double fraction}) projectOntoSegment(
  NavigationCoordinate point,
  NavigationCoordinate a,
  NavigationCoordinate b,
) {
  final cosLat = math.cos(_radians(point.latitude));
  double x(NavigationCoordinate c) =>
      _radians(c.longitude) * cosLat * _earthRadiusMeters;
  double y(NavigationCoordinate c) => _radians(c.latitude) * _earthRadiusMeters;

  final ax = x(a),
      ay = y(a),
      bx = x(b),
      by = y(b),
      px = x(point),
      py = y(point);
  final dx = bx - ax, dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  final fraction = lengthSquared == 0
      ? 0.0
      : (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
  final cx = ax + fraction * dx, cy = ay + fraction * dy;
  final distance = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  return (distanceMeters: distance, fraction: fraction);
}

double _radians(double degrees) => degrees * math.pi / 180;
