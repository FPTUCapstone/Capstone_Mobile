import 'dart:math' as math;

import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/geo_distance.dart';

/// Detects arrival at a stop once the Traveler stays inside its radius for the
/// dwell time. Detection only proposes an arrival; the Traveler confirms it.
final class ArrivalDetector {
  ArrivalDetector({
    this.radiusMeters = 50,
    this.maxAccuracyAllowanceMeters = 30,
    this.dwell = const Duration(seconds: 20),
    this.exitFactor = 1.5,
  });

  final double radiusMeters;
  final double maxAccuracyAllowanceMeters;
  final Duration dwell;

  /// A suppressed stop is released once the Traveler is farther than
  /// `exitFactor × radius`.
  final double exitFactor;

  final Map<int, DateTime> _enteredAt = {};
  final Set<int> _suppressed = {};

  /// Returns the nearest stop whose dwell time is satisfied, if any.
  int? update({
    required NavigationPosition position,
    required Iterable<NavigationSessionItem> candidates,
  }) {
    final radius =
        radiusMeters +
        math.min(position.accuracyMeters ?? 0, maxAccuracyAllowanceMeters);
    int? arrivedItemId;
    var arrivedDistance = double.infinity;
    final candidateIds = <int>{};

    for (final item in candidates) {
      candidateIds.add(item.itemId);
      final distance = distanceMeters(
        position.coordinate,
        NavigationCoordinate(
          latitude: item.latitude,
          longitude: item.longitude,
        ),
      );
      if (distance > radius) {
        _enteredAt.remove(item.itemId);
        if (distance > radius * exitFactor) _suppressed.remove(item.itemId);
        continue;
      }
      if (_suppressed.contains(item.itemId)) continue;

      final enteredAt = _enteredAt.putIfAbsent(
        item.itemId,
        () => position.timestamp,
      );
      if (position.timestamp.difference(enteredAt) >= dwell &&
          distance < arrivedDistance) {
        arrivedItemId = item.itemId;
        arrivedDistance = distance;
      }
    }

    _enteredAt.removeWhere((id, _) => !candidateIds.contains(id));
    return arrivedItemId;
  }

  /// Whether the Traveler is clearly away from [item] again (beyond
  /// `exitFactor × radius`), so a pending arrival question no longer applies.
  bool hasLeft({
    required NavigationPosition position,
    required NavigationSessionItem item,
  }) {
    final radius =
        radiusMeters +
        math.min(position.accuracyMeters ?? 0, maxAccuracyAllowanceMeters);
    final distance = distanceMeters(
      position.coordinate,
      NavigationCoordinate(latitude: item.latitude, longitude: item.longitude),
    );
    return distance > radius * exitFactor;
  }

  /// The Traveler answered "Not yet": do not propose this stop again until the
  /// Traveler has left its area.
  void suppress(int itemId) {
    _suppressed.add(itemId);
    _enteredAt.remove(itemId);
  }

  void reset() {
    _enteredAt.clear();
    _suppressed.clear();
  }
}
