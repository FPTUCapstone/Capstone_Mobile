import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';

final class NavigationCoordinate extends Equatable {
  const NavigationCoordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [latitude, longitude];
}

/// A device position fix used for navigation progress.
final class NavigationPosition extends Equatable {
  const NavigationPosition({
    required this.coordinate,
    required this.timestamp,
    this.accuracyMeters,
  });

  final NavigationCoordinate coordinate;
  final DateTime timestamp;
  final double? accuracyMeters;

  @override
  List<Object?> get props => [coordinate, timestamp, accuracyMeters];
}

/// A turn-by-turn route from the directions provider to a single target stop.
final class NavigationRoute extends Equatable {
  const NavigationRoute({
    required this.geometry,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });

  final List<NavigationCoordinate> geometry;
  final double distanceMeters;
  final double durationSeconds;
  final List<NavigationStep> steps;

  @override
  List<Object?> get props => [geometry, distanceMeters, durationSeconds, steps];
}

final class NavigationStep extends Equatable {
  const NavigationStep({
    required this.instruction,
    required this.direction,
    required this.location,
    required this.distanceMeters,
  });

  final String instruction;
  final ManeuverDirection direction;

  /// Where the maneuver happens.
  final NavigationCoordinate location;

  /// Length of the step that follows the maneuver.
  final double distanceMeters;

  @override
  List<Object?> get props => [instruction, direction, location, distanceMeters];
}
