import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_route_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_map_data.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_map.dart';

/// Itinerary overview map (D7): numbered stops coloured by type, start/end,
/// and the route of every leg. Uses Mapbox when a token is configured,
/// otherwise a drawn fallback with the same markers.
final class ItineraryMap extends StatelessWidget {
  const ItineraryMap({
    required this.data,
    required this.lines,
    required this.useMapbox,
    this.highlightedMarkerId,
    this.onMarkerTap,
    this.mapKey,
    this.height = 260,
    super.key,
  });

  final ItineraryMapData data;
  final List<ItineraryRouteLine> lines;
  final bool useMapbox;
  final int? highlightedMarkerId;
  final ValueChanged<int>? onMarkerTap;
  final GlobalKey<TripMapState>? mapKey;
  final double height;

  static Color colorOf(ItineraryMarkerKind kind) => switch (kind) {
    ItineraryMarkerKind.start => AppColors.success,
    ItineraryMarkerKind.attraction => AppColors.primary,
    ItineraryMarkerKind.food => AppColors.secondary,
    ItineraryMarkerKind.end => AppColors.ink,
  };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: useMapbox
            ? TripMap(
                key: mapKey,
                mapWidgetKey: const ValueKey('mapbox-itinerary-map'),
                camera: TripMapCamera.fitMarkers,
                showUserLocation: false,
                onMarkerTap: onMarkerTap,
                markers: [
                  for (final marker in data.markers)
                    TripMapMarker(
                      id: marker.id,
                      coordinate: marker.coordinate,
                      label: marker.itemId == null
                          ? marker.label
                          : '${marker.label}. ${marker.title}',
                      color: colorOf(marker.kind),
                      radius: marker.id == highlightedMarkerId ? 11 : 8,
                    ),
                ],
                lines: [
                  for (final line in lines)
                    TripMapLine(
                      points: line.points,
                      color: line.isStraight
                          ? AppColors.muted
                          : AppColors.primary,
                      width: line.isStraight ? 3 : 5,
                    ),
                ],
              )
            : ItineraryMapCanvas(
                data: data,
                lines: lines,
                highlightedMarkerId: highlightedMarkerId,
                onMarkerTap: onMarkerTap,
              ),
      ),
    );
  }
}

/// Drawn map used without a Mapbox token: real positions projected onto the
/// box, route lines, and tappable markers.
final class ItineraryMapCanvas extends StatelessWidget {
  const ItineraryMapCanvas({
    required this.data,
    required this.lines,
    this.highlightedMarkerId,
    this.onMarkerTap,
    super.key = const Key('itinerary_map_canvas'),
  });

  final ItineraryMapData data;
  final List<ItineraryRouteLine> lines;
  final int? highlightedMarkerId;
  final ValueChanged<int>? onMarkerTap;

  static const _markerSize = 26.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final projection = _Projection.fit([
          for (final marker in data.markers) marker.coordinate,
          for (final line in lines) ...line.points,
        ], size);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _RoutePainter(
                  lines: [
                    for (final line in lines)
                      (
                        [for (final point in line.points) projection(point)],
                        line.isStraight,
                      ),
                  ],
                ),
              ),
            ),
            for (final marker in data.markers)
              Builder(
                builder: (context) {
                  final position = projection(marker.coordinate);
                  final isHighlighted = marker.id == highlightedMarkerId;
                  final extent = isHighlighted ? _markerSize + 8 : _markerSize;
                  return Positioned(
                    left: position.dx - extent / 2,
                    top: position.dy - extent / 2,
                    width: extent,
                    height: extent,
                    child: GestureDetector(
                      key: ValueKey('map_marker_${marker.id}'),
                      onTap: onMarkerTap == null
                          ? null
                          : () => onMarkerTap!(marker.id),
                      child: Semantics(
                        label: marker.title,
                        button: onMarkerTap != null,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: ItineraryMap.colorOf(marker.kind),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Center(
                            child: marker.itemId == null
                                ? Icon(
                                    marker.kind == ItineraryMarkerKind.start
                                        ? Icons.trip_origin
                                        : Icons.flag,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : Text(
                                    marker.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            Positioned(
              left: AppSpacing.sm,
              bottom: AppSpacing.xs,
              child: Text(
                'Bản đồ minh họa',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Maps coordinates linearly into a box with padding (north up).
final class _Projection {
  _Projection(this._project);

  factory _Projection.fit(List<NavigationCoordinate> points, Size size) {
    const padding = 24.0;
    if (points.isEmpty || size.isEmpty) {
      return _Projection((_) => Offset(size.width / 2, size.height / 2));
    }
    final minLat = points.map((point) => point.latitude).reduce(math.min);
    final maxLat = points.map((point) => point.latitude).reduce(math.max);
    final minLng = points.map((point) => point.longitude).reduce(math.min);
    final maxLng = points.map((point) => point.longitude).reduce(math.max);
    final latSpan = math.max(maxLat - minLat, 0.000001);
    final lngSpan = math.max(maxLng - minLng, 0.000001);
    final width = math.max(size.width - padding * 2, 1.0);
    final height = math.max(size.height - padding * 2, 1.0);
    return _Projection(
      (point) => Offset(
        padding + (point.longitude - minLng) / lngSpan * width,
        padding + (maxLat - point.latitude) / latSpan * height,
      ),
    );
  }

  final Offset Function(NavigationCoordinate) _project;

  Offset call(NavigationCoordinate point) => _project(point);
}

final class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.lines});

  final List<(List<Offset>, bool)> lines;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEFF3F8),
    );
    for (final (points, isStraight) in lines) {
      if (points.length < 2) continue;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = isStraight ? AppColors.muted : AppColors.primary
          ..strokeWidth = isStraight ? 3 : 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => true;
}
