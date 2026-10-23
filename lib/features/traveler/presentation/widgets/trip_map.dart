import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';

/// A circle marker with a text label below it.
final class TripMapMarker extends Equatable {
  const TripMapMarker({
    required this.id,
    required this.coordinate,
    required this.label,
    required this.color,
    this.radius = 8,
  });

  final int id;
  final NavigationCoordinate coordinate;
  final String label;
  final Color color;
  final double radius;

  @override
  List<Object?> get props => [id, coordinate, label, color, radius];
}

final class TripMapLine extends Equatable {
  const TripMapLine({
    required this.points,
    this.color = AppColors.primary,
    this.width = 6,
    this.opacity = 0.85,
  });

  final List<NavigationCoordinate> points;
  final Color color;
  final double width;
  final double opacity;

  @override
  List<Object?> get props => [points, color, width, opacity];
}

/// Whether the camera must frame the markers again: on the first draw, or
/// when stops were added, removed or moved. Colour or size changes do not count.
bool tripMapNeedsFit(List<TripMapMarker>? previous, List<TripMapMarker> next) {
  if (previous == null || previous.length != next.length) return true;
  for (var i = 0; i < next.length; i++) {
    if (previous[i].id != next[i].id ||
        previous[i].coordinate != next[i].coordinate) {
      return true;
    }
  }
  return false;
}

/// How the camera behaves: follow the device position (navigation), or frame
/// all markers (itinerary overview).
enum TripMapCamera { followPuck, fitMarkers }

/// Mapbox map shared by the active trip and the itinerary detail: route
/// lines, circle markers with labels, optional location puck. Overlays are
/// redrawn whenever [markers] or [lines] change.
class TripMap extends StatefulWidget {
  const TripMap({
    super.key,
    required this.markers,
    required this.lines,
    this.camera = TripMapCamera.followPuck,
    this.initialFocus,
    this.showUserLocation = true,
    this.onMarkerTap,
    this.mapWidgetKey = const ValueKey('mapbox-navigation-map'),
  });

  final List<TripMapMarker> markers;
  final List<TripMapLine> lines;
  final TripMapCamera camera;

  /// Where the camera starts before the first fit or follow.
  final NavigationCoordinate? initialFocus;
  final bool showUserLocation;
  final ValueChanged<int>? onMarkerTap;

  /// Key of the native map view; each kind of map uses its own.
  final Key mapWidgetKey;

  @override
  State<TripMap> createState() => TripMapState();
}

class TripMapState extends State<TripMap> {
  final _viewportController = ViewportController();
  MapboxMap? _map;
  PolylineAnnotationManager? _routeLayer;
  CircleAnnotationManager? _stopLayer;
  PointAnnotationManager? _labelLayer;
  Cancelable? _tapSubscription;
  Future<void> _syncQueue = Future.value();
  bool _isFollowing = false;
  StreamSubscription<Object?>? _panSubscription;

  static const _followPuck = FollowPuckViewportState(
    zoom: 16,
    bearing: FollowPuckViewportStateBearingCourse(),
    pitch: 0,
  );

  /// Resumes following the Traveler's position.
  void recenter() {
    _isFollowing = true;
    _viewportController.moveTo(
      _followPuck,
      transition: const EasingViewportTransition(
        curve: Curves.easeInOut,
        duration: Duration(milliseconds: 600),
      ),
    );
  }

  /// Moves the camera to [coordinate] (e.g. a timeline row was tapped).
  Future<void> focus(NavigationCoordinate coordinate) async {
    final map = _map;
    if (map == null) return;
    _releaseCamera();
    try {
      await map.easeTo(
        CameraOptions(center: _point(coordinate), zoom: 15),
        MapAnimationOptions(duration: 500),
      );
    } catch (_) {
      // The map may be closing; the next focus retries.
    }
  }

  /// The Traveler panned the map: stop following so that [recenter] is a real
  /// viewport change again (re-sending the same follow state is ignored).
  void _releaseCamera() {
    if (!_isFollowing) return;
    _isFollowing = false;
    _viewportController.moveTo(IdleViewportState(), transition: null);
  }

  @override
  void didUpdateWidget(TripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parents rebuild often (location updates): redraw only on real changes.
    if (!listEquals(oldWidget.markers, widget.markers) ||
        !listEquals(oldWidget.lines, widget.lines)) {
      // Style-only changes (a selected stop grows) keep the camera, so a
      // focus() ease is not undone by a new fit.
      _scheduleSync(
        fit:
            widget.camera == TripMapCamera.fitMarkers &&
            tripMapNeedsFit(oldWidget.markers, widget.markers),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_panSubscription?.cancel());
    _tapSubscription?.cancel();
    _viewportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focus =
        widget.initialFocus ??
        (widget.markers.isEmpty ? null : widget.markers.first.coordinate);
    return MapWidget(
      key: widget.mapWidgetKey,
      viewport: CameraViewportState(
        center: focus == null ? null : _point(focus),
        zoom: widget.camera == TripMapCamera.followPuck ? 14 : 12,
      ),
      viewportController: _viewportController,
      onMapCreated: _onMapCreated,
    );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _panSubscription = map.gestures.pan.gestureEvents.listen(
      (_) => _releaseCamera(),
    );
    try {
      await map.location.updateSettings(
        LocationComponentSettings(
          enabled: widget.showUserLocation,
          pulsingEnabled: widget.showUserLocation,
          puckBearingEnabled: widget.showUserLocation,
        ),
      );
      await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
      final routeLayer = await map.annotations
          .createPolylineAnnotationManager();
      final stopLayer = await map.annotations.createCircleAnnotationManager();
      final labelLayer = await map.annotations.createPointAnnotationManager();
      if (!mounted) return;
      _routeLayer = routeLayer;
      _stopLayer = stopLayer;
      _labelLayer = labelLayer;
      _tapSubscription = stopLayer.tapEvents(
        onTap: (annotation) {
          final id = annotation.customData?['markerId'];
          if (id is int) widget.onMarkerTap?.call(id);
        },
      );
    } catch (_) {
      // The page may be leaving while the native map initialises; the map
      // then simply renders without overlays.
      return;
    }
    final fit = widget.camera == TripMapCamera.fitMarkers;
    _scheduleSync(fit: fit);
    if (!fit) recenter();
  }

  void _scheduleSync({bool fit = false}) {
    if (_map == null) return;
    _syncQueue = _syncQueue.then((_) => _sync(fit: fit)).catchError((Object _) {
      // A failed redraw must not break the page; the next update retries.
    });
  }

  Future<void> _sync({required bool fit}) async {
    final map = _map;
    final routeLayer = _routeLayer;
    final stopLayer = _stopLayer;
    final labelLayer = _labelLayer;
    if (!mounted ||
        map == null ||
        routeLayer == null ||
        stopLayer == null ||
        labelLayer == null) {
      return;
    }

    await routeLayer.deleteAll();
    final lines = widget.lines.where((line) => line.points.length >= 2);
    if (lines.isNotEmpty) {
      await routeLayer.createMulti([
        for (final line in lines)
          PolylineAnnotationOptions(
            geometry: LineString(
              coordinates: [
                for (final point in line.points)
                  Position(point.longitude, point.latitude),
              ],
            ),
            lineColor: line.color.toARGB32(),
            lineWidth: line.width,
            lineOpacity: line.opacity,
          ),
      ]);
    }

    await stopLayer.deleteAll();
    await labelLayer.deleteAll();
    final markers = widget.markers;
    if (markers.isEmpty) return;
    await stopLayer.createMulti([
      for (final marker in markers)
        CircleAnnotationOptions(
          geometry: _point(marker.coordinate),
          circleRadius: marker.radius,
          circleColor: marker.color.toARGB32(),
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2,
          customData: {'markerId': marker.id},
        ),
    ]);
    // Markers at the same spot would print their labels on top of each
    // other: stack each extra label one line lower.
    final labelRows = <String, int>{};
    await labelLayer.createMulti([
      for (final marker in markers)
        PointAnnotationOptions(
          geometry: _point(marker.coordinate),
          textField: marker.label,
          textSize: 12,
          textOffset: [
            0,
            1.6 +
                1.3 *
                    (labelRows.update(
                          '${marker.coordinate.latitude},'
                          '${marker.coordinate.longitude}',
                          (row) => row + 1,
                          ifAbsent: () => 1,
                        ) -
                        1),
          ],
          textColor: AppColors.ink.toARGB32(),
          textHaloColor: Colors.white.toARGB32(),
          textHaloWidth: 1.5,
        ),
    ]);

    if (fit) {
      final camera = await map.cameraForCoordinatesPadding(
        [for (final marker in markers) _point(marker.coordinate)],
        CameraOptions(),
        MbxEdgeInsets(top: 48, left: 48, bottom: 48, right: 48),
        16,
        null,
      );
      if (mounted) await map.setCamera(camera);
    }
  }

  static Point _point(NavigationCoordinate coordinate) =>
      Point(coordinates: Position(coordinate.longitude, coordinate.latitude));
}
