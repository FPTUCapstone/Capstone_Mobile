import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/mapbox_navigation_map.dart';

/// The active-trip map keeps its markers after moving to the shared map.
void main() {
  NavigationSessionItem item(int id, NavigationItemStatus status) =>
      NavigationSessionItem(
        itemId: id,
        sequenceNo: id,
        poiId: id * 10,
        poiName: 'Stop $id',
        latitude: 16.0 + id / 100,
        longitude: 108.2,
        plannedArrival: DateTime.utc(2026, 10, 18, 1),
        plannedDeparture: DateTime.utc(2026, 10, 18, 2),
        isMandatory: false,
        status: status,
        reachedAt: null,
        skippedAt: null,
        stopNumber: id,
      );

  test('target is larger and highlighted, others coloured by progress', () {
    final markers = navigationMapMarkers([
      item(1, NavigationItemStatus.reached),
      item(2, NavigationItemStatus.pending),
      item(3, NavigationItemStatus.skipped),
      item(4, NavigationItemStatus.pending),
    ], 2);

    expect(markers.map((marker) => marker.color), [
      CoastalPalette.light.success,
      CoastalPalette.light.primary,
      const Color(0xFFD97706),
      CoastalPalette.light.secondary,
    ]);
    expect(markers.map((marker) => marker.radius), [9, 12, 9, 9]);
    expect(markers.map((marker) => marker.badge), ['✓', '2', '3', '4']);
    expect(markers.map((marker) => marker.highlighted), [
      false,
      true,
      false,
      false,
    ]);
    expect(markers.first.label, '1. Stop 1');
    expect(markers.first.coordinate.latitude, 16.01);
  });
}
