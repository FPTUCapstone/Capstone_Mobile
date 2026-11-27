import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_map_data.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_map.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/mapbox_navigation_map.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_map.dart';

void main() {
  TripMapMarker marker(
    int id,
    double latitude, {
    double radius = 8,
    Color color = Colors.blue,
  }) => TripMapMarker(
    id: id,
    coordinate: NavigationCoordinate(latitude: latitude, longitude: 108.2),
    label: '$id',
    color: color,
    radius: radius,
  );

  final markers = [marker(1, 16.0), marker(2, 16.1)];

  test('the first draw frames all markers', () {
    expect(tripMapNeedsFit(null, markers), isTrue);
  });

  test('a style-only change (selected stop) keeps the camera', () {
    expect(
      tripMapNeedsFit(markers, [
        marker(1, 16.0),
        marker(2, 16.1, radius: 11, color: Colors.orange),
      ]),
      isFalse,
    );
  });

  test('moved, added or removed stops are framed again', () {
    expect(
      tripMapNeedsFit(markers, [marker(1, 16.0), marker(2, 16.2)]),
      isTrue,
    );
    expect(tripMapNeedsFit(markers, [...markers, marker(3, 16.3)]), isTrue);
    expect(tripMapNeedsFit(markers, [marker(1, 16.0)]), isTrue);
  });

  test('itinerary map colors and route ramp match Web Mapbox styling', () {
    expect(
      ItineraryMap.colorOf(ItineraryMarkerKind.start),
      const Color(0xFF1C2928),
    );
    expect(
      ItineraryMap.colorOf(ItineraryMarkerKind.attraction),
      const Color(0xFF103B39),
    );
    expect(
      ItineraryMap.colorOf(ItineraryMarkerKind.food),
      const Color(0xFFD97706),
    );
    expect(
      ItineraryMap.colorOf(ItineraryMarkerKind.end),
      const Color(0xFF7C3AED),
    );
    expect(itineraryRouteLegColor(0, 3), const Color(0xFF174B4A));
    expect(itineraryRouteLegColor(2, 3), const Color(0xFF7C3AED));
    expect(itineraryRouteLegColor(0, 1), const Color(0xFF174B4A));
  });

  test('tripMapCircleRing builds a closed geodesic ring around center', () {
    const center = NavigationCoordinate(latitude: 16.0544, longitude: 108.2022);
    final ring = tripMapCircleRing(center, 10, segments: 24);
    expect(ring, hasLength(25));
    expect(ring.first.latitude, closeTo(ring.last.latitude, 1e-6));
    expect(ring.first.longitude, closeTo(ring.last.longitude, 1e-6));
    expect(ring[6].latitude, greaterThan(center.latitude));
    expect(ring[18].latitude, lessThan(center.latitude));
  });

  test('navigationMapMarkers uses Coastal numbered badges and checkmarks', () {
    final now = DateTime.utc(2026, 11, 25, 10);
    final items = [
      NavigationSessionItem(
        itemId: 1,
        sequenceNo: 1,
        poiId: 10,
        poiName: 'Non Nuoc',
        latitude: 16.0,
        longitude: 108.2,
        plannedArrival: now,
        plannedDeparture: now,
        isMandatory: false,
        status: NavigationItemStatus.reached,
        reachedAt: now,
        skippedAt: null,
      ),
      NavigationSessionItem(
        itemId: 2,
        sequenceNo: 2,
        poiId: 11,
        poiName: 'My Khe',
        latitude: 16.07,
        longitude: 108.24,
        plannedArrival: now,
        plannedDeparture: now,
        isMandatory: true,
        status: NavigationItemStatus.pending,
        reachedAt: null,
        skippedAt: null,
      ),
    ];

    final navMarkers = navigationMapMarkers(items, 2);
    expect(navMarkers[0].badge, '✓');
    expect(navMarkers[0].color, CoastalPalette.light.success);
    expect(navMarkers[0].highlighted, isFalse);
    expect(navMarkers[1].badge, '2');
    expect(navMarkers[1].color, CoastalPalette.light.primary);
    expect(navMarkers[1].highlighted, isTrue);
  });
}
