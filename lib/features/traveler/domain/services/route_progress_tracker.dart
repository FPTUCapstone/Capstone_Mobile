import 'dart:math' as math;

import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/geo_distance.dart';

final class RouteProgress {
  const RouteProgress({
    required this.distanceFromRouteMeters,
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
    required this.nextStep,
    required this.distanceToNextStepMeters,
  });

  final double distanceFromRouteMeters;
  final double remainingDistanceMeters;
  final double remainingDurationSeconds;
  final NavigationStep? nextStep;
  final double distanceToNextStepMeters;
}

/// Matches device positions against one route: distance from the line, what is
/// left to drive, and the upcoming maneuver.
final class RouteProgressTracker {
  RouteProgressTracker(this.route) {
    final geometry = route.geometry;
    _cumulative = List<double>.filled(geometry.length, 0);
    for (var i = 1; i < geometry.length; i++) {
      _cumulative[i] =
          _cumulative[i - 1] + distanceMeters(geometry[i - 1], geometry[i]);
    }
    var searchFrom = 0;
    _stepVertices = [
      for (final step in route.steps)
        searchFrom = _nearestVertex(step.location, from: searchFrom),
    ];
  }

  final NavigationRoute route;
  late final List<double> _cumulative;
  late final List<int> _stepVertices;

  RouteProgress progress(NavigationCoordinate position) {
    final geometry = route.geometry;
    if (geometry.length < 2) {
      final distance = geometry.isEmpty
          ? 0.0
          : distanceMeters(position, geometry.first);
      return RouteProgress(
        distanceFromRouteMeters: distance,
        remainingDistanceMeters: route.distanceMeters,
        remainingDurationSeconds: route.durationSeconds,
        nextStep: route.steps.isEmpty ? null : route.steps.last,
        distanceToNextStepMeters: route.distanceMeters,
      );
    }

    var bestSegment = 0;
    var bestFraction = 0.0;
    var bestDistance = double.infinity;
    for (var i = 0; i < geometry.length - 1; i++) {
      final projection = projectOntoSegment(
        position,
        geometry[i],
        geometry[i + 1],
      );
      if (projection.distanceMeters < bestDistance) {
        bestDistance = projection.distanceMeters;
        bestSegment = i;
        bestFraction = projection.fraction;
      }
    }

    final total = _cumulative.last;
    final segmentLength =
        _cumulative[bestSegment + 1] - _cumulative[bestSegment];
    final along = _cumulative[bestSegment] + bestFraction * segmentLength;
    final remaining = math.max(0.0, total - along);

    NavigationStep? nextStep;
    var distanceToNextStep = remaining;
    for (var i = 0; i < route.steps.length; i++) {
      if (_stepVertices[i] > bestSegment) {
        nextStep = route.steps[i];
        distanceToNextStep = math.max(
          0.0,
          _cumulative[_stepVertices[i]] - along,
        );
        break;
      }
    }
    nextStep ??= route.steps.isEmpty ? null : route.steps.last;

    return RouteProgress(
      distanceFromRouteMeters: bestDistance,
      remainingDistanceMeters: remaining,
      remainingDurationSeconds: total <= 0
          ? 0
          : route.durationSeconds * (remaining / total),
      nextStep: nextStep,
      distanceToNextStepMeters: distanceToNextStep,
    );
  }

  int _nearestVertex(NavigationCoordinate location, {required int from}) {
    var best = from;
    var bestDistance = double.infinity;
    for (var i = from; i < route.geometry.length; i++) {
      final distance = distanceMeters(location, route.geometry[i]);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return best;
  }
}
