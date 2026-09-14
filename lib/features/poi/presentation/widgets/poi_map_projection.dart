import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';

abstract final class PoiMapProjection {
  static Map<int, Offset> project(
    List<PoiSummary> pois,
    Size size, {
    double padding = 40,
  }) {
    if (pois.isEmpty || size.isEmpty) return const {};
    if (pois.length == 1) {
      return {pois.single.id: Offset(size.width / 2, size.height / 2)};
    }

    final minLatitude = pois.map((poi) => poi.latitude).reduce(math.min);
    final maxLatitude = pois.map((poi) => poi.latitude).reduce(math.max);
    final minLongitude = pois.map((poi) => poi.longitude).reduce(math.min);
    final maxLongitude = pois.map((poi) => poi.longitude).reduce(math.max);
    final latitudeSpan = math.max(maxLatitude - minLatitude, 0.000001);
    final longitudeSpan = math.max(maxLongitude - minLongitude, 0.000001);
    final usableWidth = math.max(size.width - (padding * 2), 0).toDouble();
    final usableHeight = math.max(size.height - (padding * 2), 0).toDouble();

    return {
      for (final poi in pois)
        poi.id: Offset(
          padding +
              ((poi.longitude - minLongitude) / longitudeSpan) * usableWidth,
          padding +
              ((maxLatitude - poi.latitude) / latitudeSpan) * usableHeight,
        ),
    };
  }
}
