import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
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
      AppColors.muted,
      AppColors.secondary,
      AppColors.warning,
      AppColors.primary,
    ]);
    expect(markers.map((marker) => marker.radius), [8, 11, 8, 8]);
    expect(markers.first.label, '1. Stop 1');
    expect(markers.first.coordinate.latitude, 16.01);
  });
}
