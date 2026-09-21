import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_map_projection.dart';

void main() {
  test('fit bounds keeps every loaded POI inside the padded viewport', () {
    const pois = [
      PoiSummary(
        id: 1,
        name: 'North west',
        categoryId: 1,
        categoryName: 'A',
        latitude: 20,
        longitude: 100,
        indoorOutdoor: 'Outdoor',
        averageVisitDurationMinutes: 60,
        hasShelter: false,
        reviewCount: 0,
        isOpenNow: true,
      ),
      PoiSummary(
        id: 2,
        name: 'South east',
        categoryId: 1,
        categoryName: 'A',
        latitude: -20,
        longitude: 130,
        indoorOutdoor: 'Outdoor',
        averageVisitDurationMinutes: 60,
        hasShelter: false,
        reviewCount: 0,
        isOpenNow: false,
      ),
    ];
    const size = Size(320, 500);

    final points = PoiMapProjection.project(pois, size, padding: 32);

    expect(points, hasLength(2));
    for (final point in points.values) {
      expect(point.dx, inInclusiveRange(32, 288));
      expect(point.dy, inInclusiveRange(32, 468));
    }
  });

  test('a single POI is centered instead of dividing by zero', () {
    const poi = PoiSummary(
      id: 1,
      name: 'Only',
      categoryId: 1,
      categoryName: 'A',
      latitude: 16,
      longitude: 108,
      indoorOutdoor: 'Outdoor',
      averageVisitDurationMinutes: 60,
      hasShelter: false,
      reviewCount: 0,
      isOpenNow: true,
    );

    expect(
      PoiMapProjection.project(const [poi], const Size(320, 500))[1],
      const Offset(160, 250),
    );
  });
}
