import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxStyles;
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_route_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_map_data.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_map.dart';

/// Color ramp matching Web's `mapboxStyle.ts` (`#174B4A` -> `#7C3AED`) so
/// consecutive road legs show trip progression from start to end.
Color itineraryRouteLegColor(int index, int count) {
  const start = Color(0xFF174B4A);
  const end = Color(0xFF7C3AED);
  final t = count <= 1 ? 0.0 : (index / (count - 1)).clamp(0.0, 1.0);
  return Color.lerp(start, end, t)!;
}

/// Itinerary overview map (D7): numbered stops coloured by type, start/end,
/// and the route of every leg. Uses Mapbox (`streets-v12`) matching Web's
/// custom styling when a token is configured, otherwise a drawn fallback.
final class ItineraryMap extends StatelessWidget {
  const ItineraryMap({
    required this.data,
    required this.lines,
    required this.useMapbox,
    this.highlightedMarkerId,
    this.onMarkerTap,
    this.mapKey,
    this.height = 230,
    super.key,
  });

  final ItineraryMapData data;
  final List<ItineraryRouteLine> lines;
  final bool useMapbox;
  final int? highlightedMarkerId;
  final ValueChanged<int>? onMarkerTap;
  final GlobalKey<TripMapState>? mapKey;
  final double height;

  /// Matches Web `MARKER_COLORS` in `mapGeometry.ts`.
  static Color colorOf(ItineraryMarkerKind kind) => switch (kind) {
    ItineraryMarkerKind.start => const Color(0xFF1C2928),
    ItineraryMarkerKind.attraction => const Color(0xFF103B39),
    ItineraryMarkerKind.food => const Color(0xFFD97706),
    ItineraryMarkerKind.end => const Color(0xFF7C3AED),
  };

  static String badgeOf(ItineraryMapMarker marker) => switch (marker.kind) {
    ItineraryMarkerKind.start => 'B',
    ItineraryMarkerKind.end => 'K',
    ItineraryMarkerKind.attraction || ItineraryMarkerKind.food => marker.label,
  };

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    final totalLegs = lines.length;
    final hasStart = data.markers.any(
      (m) => m.kind == ItineraryMarkerKind.start,
    );
    final hasFood = data.markers.any((m) => m.kind == ItineraryMarkerKind.food);
    final hasEnd = data.markers.any((m) => m.kind == ItineraryMarkerKind.end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: height,
            child: useMapbox
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      TripMap(
                        key: mapKey,
                        mapWidgetKey: const ValueKey('mapbox-itinerary-map'),
                        styleUri: MapboxStyles.MAPBOX_STREETS,
                        camera: TripMapCamera.fitMarkers,
                        showUserLocation: false,
                        onMarkerTap: onMarkerTap,
                        markers: [
                          for (final marker in data.markers)
                            TripMapMarker(
                              id: marker.id,
                              coordinate: marker.coordinate,
                              badge: badgeOf(marker),
                              label: marker.itemId == null
                                  ? marker.label
                                  : '${marker.label}. ${marker.title}',
                              color: colorOf(marker.kind),
                              highlighted: marker.id == highlightedMarkerId,
                              showLabel: marker.id == highlightedMarkerId,
                            ),
                        ],
                        lines: [
                          for (var i = 0; i < totalLegs; i++)
                            TripMapLine(
                              points: lines[i].points,
                              color: lines[i].isStraight
                                  ? const Color(0xFF174B4A)
                                  : itineraryRouteLegColor(i, totalLegs),
                              width: lines[i].isStraight ? 3.0 : 4.5,
                              opacity: lines[i].isStraight ? 0.55 : 0.95,
                              casingColor: lines[i].isStraight
                                  ? null
                                  : Colors.white,
                              casingWidth: lines[i].isStraight ? null : 7.5,
                            ),
                        ],
                      ),
                      if (mapKey != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _MapControlsPill(
                            palette: palette,
                            onZoomIn: () => mapKey!.currentState?.zoomBy(1.2),
                            onZoomOut: () => mapKey!.currentState?.zoomBy(-1.2),
                            onFitAll: () => mapKey!.currentState?.fitAll(),
                          ),
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
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            if (hasStart)
              _LegendDot(
                color: colorOf(ItineraryMarkerKind.start),
                badge: 'B',
                label: 'Xuất phát',
                textColor: palette.secondary,
              ),
            _LegendDot(
              color: colorOf(ItineraryMarkerKind.attraction),
              badge: '1',
              label: 'Tham quan',
              textColor: palette.secondary,
            ),
            if (hasFood)
              _LegendDot(
                color: colorOf(ItineraryMarkerKind.food),
                badge: '2',
                label: 'Ăn uống',
                textColor: palette.secondary,
              ),
            if (hasEnd)
              _LegendDot(
                color: colorOf(ItineraryMarkerKind.end),
                badge: 'K',
                label: 'Kết thúc',
                textColor: palette.secondary,
              ),
          ],
        ),
      ],
    );
  }
}

final class _MapControlsPill extends StatelessWidget {
  const _MapControlsPill({
    required this.palette,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitAll,
  });

  final CoastalPalette palette;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitAll;

  @override
  Widget build(BuildContext context) {
    Widget button({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
    }) => Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 17, color: palette.ink),
        ),
      ),
    );

    return Material(
      color: palette.surface.withValues(alpha: 0.94),
      elevation: 2,
      shadowColor: const Color(0x26000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(icon: Icons.add, tooltip: 'Phóng to', onTap: onZoomIn),
          Container(width: 30, height: 1, color: palette.border),
          button(icon: Icons.remove, tooltip: 'Thu nhỏ', onTap: onZoomOut),
          Container(width: 30, height: 1, color: palette.border),
          button(
            icon: Icons.center_focus_strong_outlined,
            tooltip: 'Xem toàn bộ lộ trình',
            onTap: onFitAll,
          ),
        ],
      ),
    );
  }
}

final class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.badge,
    required this.label,
    required this.textColor,
  });

  final Color color;
  final String badge;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 15,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            badge,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5, color: textColor)),
      ],
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
                            child: Text(
                              ItineraryMap.badgeOf(marker),
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
    for (var i = 0; i < lines.length; i++) {
      final (points, isStraight) = lines[i];
      if (points.length < 2) continue;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      if (!isStraight) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..strokeWidth = 7.5
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.stroke,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = isStraight
              ? const Color(0x8C174B4A)
              : itineraryRouteLegColor(i, lines.length)
          ..strokeWidth = isStraight ? 3 : 4.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter oldDelegate) => true;
}
