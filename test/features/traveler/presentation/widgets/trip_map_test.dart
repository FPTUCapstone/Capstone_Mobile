import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
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
}
