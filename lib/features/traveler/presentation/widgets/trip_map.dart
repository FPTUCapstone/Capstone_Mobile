import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';

/// A map marker: either a plain circle with a label below it, or (when [badge]
/// is set) a Web-style circular numbered pin rendered as a crisp HiDPI bitmap.
final class TripMapMarker extends Equatable {
  const TripMapMarker({
    required this.id,
    required this.coordinate,
    required this.label,
    required this.color,
    this.radius = 8,
    this.badge,
    this.highlighted = false,
    this.showLabel = true,
  });

  final int id;
  final NavigationCoordinate coordinate;
  final String label;
  final Color color;
  final double radius;

  /// Optional short symbol rendered centered inside the circular pin (e.g.
  /// `'B'`, `'1'`, `'2'`, `'K'`).
  final String? badge;
  final bool highlighted;
  final bool showLabel;

  @override
  List<Object?> get props => [
    id,
    coordinate,
    label,
    color,
    radius,
    badge,
    highlighted,
    showLabel,
  ];
}

final class TripMapLine extends Equatable {
  const TripMapLine({
    required this.points,
    this.color = AppColors.primary,
    this.width = 6,
    this.opacity = 0.85,
    this.casingColor,
    this.casingWidth,
  });

  final List<NavigationCoordinate> points;
  final Color color;
  final double width;
  final double opacity;
  final Color? casingColor;
  final double? casingWidth;

  @override
  List<Object?> get props => [
    points,
    color,
    width,
    opacity,
    casingColor,
    casingWidth,
  ];
}

final class TripMapPolygon extends Equatable {
  const TripMapPolygon({
    required this.points,
    required this.fillColor,
    this.fillOpacity = 0.16,
    this.outlineColor,
  });

  final List<NavigationCoordinate> points;
  final Color fillColor;
  final double fillOpacity;
  final Color? outlineColor;

  @override
  List<Object?> get props => [points, fillColor, fillOpacity, outlineColor];
}

/// Builds a closed geodesic circle ring around [center] with radius [radiusKm]
/// for Mapbox polygon/polyline search-radius overlays.
List<NavigationCoordinate> tripMapCircleRing(
  NavigationCoordinate center,
  double radiusKm, {
  int segments = 48,
}) {
  const kmPerLatDegree = 111.32;
  final latDelta = radiusKm / kmPerLatDegree;
  final cosLat = math
      .cos(center.latitude * math.pi / 180.0)
      .abs()
      .clamp(0.1, 1.0);
  final lngDelta = radiusKm / (kmPerLatDegree * cosLat);
  return [
    for (var i = 0; i <= segments; i++)
      NavigationCoordinate(
        latitude:
            center.latitude + latDelta * math.sin(2 * math.pi * i / segments),
        longitude:
            center.longitude + lngDelta * math.cos(2 * math.pi * i / segments),
      ),
  ];
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
    this.polygons = const [],
    this.camera = TripMapCamera.followPuck,
    this.initialFocus,
    this.showUserLocation = true,
    this.styleUri,
    this.fitPadding,
    this.onMarkerTap,
    this.mapWidgetKey = const ValueKey('mapbox-navigation-map'),
  });

  final List<TripMapMarker> markers;
  final List<TripMapLine> lines;
  final List<TripMapPolygon> polygons;
  final TripMapCamera camera;

  /// Where the camera starts before the first fit or follow.
  final NavigationCoordinate? initialFocus;
  final bool showUserLocation;
  final String? styleUri;
  final EdgeInsets? fitPadding;
  final ValueChanged<int>? onMarkerTap;

  /// Key of the native map view; each kind of map uses its own.
  final Key mapWidgetKey;

  @override
  State<TripMap> createState() => TripMapState();
}

class TripMapState extends State<TripMap> {
  final _viewportController = ViewportController();
  final _pinImageCache = <String, Uint8List>{};
  MapboxMap? _map;
  PolygonAnnotationManager? _polygonLayer;
  PolylineAnnotationManager? _casingLayer;
  PolylineAnnotationManager? _routeLayer;
  CircleAnnotationManager? _stopLayer;
  PointAnnotationManager? _pinLayer;
  PointAnnotationManager? _labelLayer;
  Cancelable? _stopTapSubscription;
  Cancelable? _pinTapSubscription;
  Future<void> _syncQueue = Future.value();
  bool _isFollowing = false;
  bool _pendingMapLoadedFit = false;
  StreamSubscription<Object?>? _panSubscription;
  late final ViewportState? _initialViewport;

  @override
  void initState() {
    super.initState();
    // Cache the initial viewport once so MapWidget.didUpdateWidget sees an
    // identical ViewportState across rebuilds (e.g. when road routes finish
    // loading or a stop is highlighted) instead of snapping the camera back
    // to the first marker.
    final focus = _initialCenter();
    _initialViewport = focus == null
        ? null
        : CameraViewportState(
            center: _point(focus),
            zoom: widget.camera == TripMapCamera.followPuck ? 14 : 11,
          );
  }

  NavigationCoordinate? _initialCenter() {
    if (widget.initialFocus != null) return widget.initialFocus;
    if (widget.markers.isEmpty) return null;
    if (widget.camera != TripMapCamera.fitMarkers ||
        widget.markers.length == 1) {
      return widget.markers.first.coordinate;
    }
    var lat = 0.0;
    var lng = 0.0;
    for (final marker in widget.markers) {
      lat += marker.coordinate.latitude;
      lng += marker.coordinate.longitude;
    }
    return NavigationCoordinate(
      latitude: lat / widget.markers.length,
      longitude: lng / widget.markers.length,
    );
  }

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
    _pendingMapLoadedFit = false;
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

  /// Adjusts the current zoom by [delta] (for +/- map controls).
  Future<void> zoomBy(double delta) async {
    final map = _map;
    if (map == null) return;
    _pendingMapLoadedFit = false;
    _releaseCamera();
    try {
      final state = await map.getCameraState();
      final nextZoom = (state.zoom + delta).clamp(3.0, 19.0);
      await map.easeTo(
        CameraOptions(zoom: nextZoom),
        MapAnimationOptions(duration: 240),
      );
    } catch (_) {
      // Ignore transient camera errors while map disposes.
    }
  }

  /// Refits the camera to show all markers, routes, and search polygons.
  Future<void> fitAll() async {
    _pendingMapLoadedFit = false;
    final wasFollowing = _isFollowing;
    _isFollowing = false;
    await _fitCamera(useViewportController: wasFollowing);
  }

  /// The Traveler panned the map: stop following so that [recenter] is a real
  /// viewport change again (re-sending the same follow state is ignored).
  void _releaseCamera() {
    _pendingMapLoadedFit = false;
    if (!_isFollowing) return;
    _isFollowing = false;
    _viewportController.moveTo(IdleViewportState(), transition: null);
  }

  @override
  void didUpdateWidget(TripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parents rebuild often (location updates): redraw only on real changes.
    final polygonsChanged = !listEquals(oldWidget.polygons, widget.polygons);
    if (!listEquals(oldWidget.markers, widget.markers) ||
        !listEquals(oldWidget.lines, widget.lines) ||
        polygonsChanged) {
      // Style-only changes (a selected stop grows) keep the camera, so a
      // focus() ease is not undone by a new fit.
      _scheduleSync(
        fit:
            widget.camera == TripMapCamera.fitMarkers &&
            (tripMapNeedsFit(oldWidget.markers, widget.markers) ||
                polygonsChanged),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_panSubscription?.cancel());
    _stopTapSubscription?.cancel();
    _pinTapSubscription?.cancel();
    _viewportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: widget.mapWidgetKey,
      styleUri: widget.styleUri ?? MapboxStyles.STANDARD,
      viewport: _initialViewport,
      viewportController: _viewportController,
      onMapCreated: _onMapCreated,
      onMapLoadedListener: (_) {
        if (_pendingMapLoadedFit &&
            mounted &&
            widget.camera == TripMapCamera.fitMarkers) {
          _pendingMapLoadedFit = false;
          _scheduleFitOnly();
        }
      },
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
      await map.compass.updateSettings(CompassSettings(enabled: false));
      // Layer order bottom -> top: search-radius polygons, road white casing,
      // colored route lines, circle stops, badged numbered pins, floating labels.
      final polygonLayer = await map.annotations
          .createPolygonAnnotationManager();
      final casingLayer = await map.annotations
          .createPolylineAnnotationManager();
      final routeLayer = await map.annotations
          .createPolylineAnnotationManager();
      final stopLayer = await map.annotations.createCircleAnnotationManager();
      final pinLayer = await map.annotations.createPointAnnotationManager();
      await pinLayer.setIconAllowOverlap(true);
      final labelLayer = await map.annotations.createPointAnnotationManager();
      if (!mounted) return;
      _polygonLayer = polygonLayer;
      _casingLayer = casingLayer;
      _routeLayer = routeLayer;
      _stopLayer = stopLayer;
      _pinLayer = pinLayer;
      _labelLayer = labelLayer;
      _stopTapSubscription = stopLayer.tapEvents(
        onTap: (annotation) {
          final id = annotation.customData?['markerId'];
          if (id is int) widget.onMarkerTap?.call(id);
        },
      );
      _pinTapSubscription = pinLayer.tapEvents(
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
    _pendingMapLoadedFit = fit;
    _scheduleSync(fit: fit);
    if (!fit) recenter();
  }

  void _scheduleSync({bool fit = false}) {
    if (_map == null) return;
    _syncQueue = _syncQueue.then((_) => _sync(fit: fit)).catchError((Object _) {
      // A failed redraw must not break the page; the next update retries.
    });
  }

  void _scheduleFitOnly() {
    if (_map == null) return;
    _syncQueue = _syncQueue.then((_) => _fitCamera()).catchError((Object _) {});
  }

  Future<void> _fitCamera({bool useViewportController = false}) async {
    final map = _map;
    final markers = widget.markers;
    if (!mounted || map == null || markers.isEmpty) return;
    final fitPoints = <Point>[
      for (final marker in markers) _point(marker.coordinate),
    ];
    for (final line in widget.lines) {
      if (line.points.length < 2) continue;
      final step = (line.points.length / 12).ceil().clamp(
        1,
        line.points.length,
      );
      for (var i = 0; i < line.points.length; i += step) {
        fitPoints.add(_point(line.points[i]));
      }
      fitPoints.add(_point(line.points.last));
    }
    for (final polygon in widget.polygons) {
      if (polygon.points.length < 3) continue;
      final step = (polygon.points.length / 12).ceil().clamp(
        1,
        polygon.points.length,
      );
      for (var i = 0; i < polygon.points.length; i += step) {
        fitPoints.add(_point(polygon.points[i]));
      }
    }
    if (fitPoints.length == 1) {
      if (useViewportController) {
        _viewportController.moveTo(
          CameraViewportState(
            center: fitPoints.first,
            zoom: 14.5,
            bearing: 0,
            pitch: 0,
          ),
          transition: const EasingViewportTransition(
            curve: Curves.easeInOut,
            duration: Duration(milliseconds: 500),
          ),
        );
      } else {
        await map.setCamera(CameraOptions(center: fitPoints.first, zoom: 14.5));
      }
      return;
    }
    final pad = widget.fitPadding;
    final camera = await map.cameraForCoordinatesPadding(
      fitPoints,
      CameraOptions(),
      MbxEdgeInsets(
        top: pad?.top ?? 72,
        left: pad?.left ?? 60,
        bottom: pad?.bottom ?? 60,
        right: pad?.right ?? 60,
      ),
      15.5,
      null,
    );
    if (!mounted) return;
    if (useViewportController) {
      _viewportController.moveTo(
        CameraViewportState(
          center: camera.center,
          zoom: camera.zoom,
          bearing: 0,
          pitch: 0,
        ),
        transition: const EasingViewportTransition(
          curve: Curves.easeInOut,
          duration: Duration(milliseconds: 500),
        ),
      );
    } else {
      await map.setCamera(camera);
    }
  }

  Future<void> _sync({required bool fit}) async {
    final map = _map;
    final polygonLayer = _polygonLayer;
    final casingLayer = _casingLayer;
    final routeLayer = _routeLayer;
    final stopLayer = _stopLayer;
    final pinLayer = _pinLayer;
    final labelLayer = _labelLayer;
    if (!mounted ||
        map == null ||
        polygonLayer == null ||
        casingLayer == null ||
        routeLayer == null ||
        stopLayer == null ||
        pinLayer == null ||
        labelLayer == null) {
      return;
    }

    await polygonLayer.deleteAll();
    final polygons = widget.polygons
        .where((polygon) => polygon.points.length >= 3)
        .toList();
    if (polygons.isNotEmpty) {
      await polygonLayer.createMulti([
        for (final polygon in polygons)
          PolygonAnnotationOptions(
            geometry: Polygon(
              coordinates: [
                [
                  for (final point in polygon.points)
                    Position(point.longitude, point.latitude),
                ],
              ],
            ),
            fillColor: polygon.fillColor.toARGB32(),
            fillOpacity: polygon.fillOpacity,
            fillOutlineColor: polygon.outlineColor?.toARGB32(),
          ),
      ]);
    }

    await casingLayer.deleteAll();
    await routeLayer.deleteAll();
    final lines = widget.lines
        .where((line) => line.points.length >= 2)
        .toList();
    if (lines.isNotEmpty) {
      final casings = lines.where((line) => line.casingColor != null).toList();
      if (casings.isNotEmpty) {
        await casingLayer.createMulti([
          for (final line in casings)
            PolylineAnnotationOptions(
              geometry: LineString(
                coordinates: [
                  for (final point in line.points)
                    Position(point.longitude, point.latitude),
                ],
              ),
              lineColor: line.casingColor!.toARGB32(),
              lineWidth: line.casingWidth ?? (line.width + 3),
              lineOpacity: line.opacity,
            ),
        ]);
      }
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
    await pinLayer.deleteAll();
    await labelLayer.deleteAll();
    final markers = widget.markers;
    if (markers.isEmpty) return;

    final circleMarkers = markers
        .where((marker) => marker.badge == null)
        .toList(growable: false);
    if (circleMarkers.isNotEmpty) {
      await stopLayer.createMulti([
        for (final marker in circleMarkers)
          CircleAnnotationOptions(
            geometry: _point(marker.coordinate),
            circleRadius: marker.radius,
            circleColor: marker.color.toARGB32(),
            circleStrokeColor: Colors.white.toARGB32(),
            circleStrokeWidth: 2,
            customData: {'markerId': marker.id},
          ),
      ]);
    }

    final badgedMarkers = markers
        .where((marker) => marker.badge != null)
        .toList(growable: false);
    if (badgedMarkers.isNotEmpty) {
      final pinOptions = <PointAnnotationOptions>[];
      for (final marker in badgedMarkers) {
        final bytes = await _pinBitmapFor(
          badge: marker.badge!,
          color: marker.color,
          highlighted: marker.highlighted,
        );
        if (!mounted) return;
        pinOptions.add(
          PointAnnotationOptions(
            geometry: _point(marker.coordinate),
            image: bytes,
            iconSize: 0.5,
            iconAnchor: IconAnchor.CENTER,
            symbolSortKey: marker.highlighted ? 10.0 : 1.0,
            customData: {'markerId': marker.id},
          ),
        );
      }
      await pinLayer.createMulti(pinOptions);
    }

    final labeledMarkers = markers
        .where((marker) => marker.showLabel && marker.label.isNotEmpty)
        .toList(growable: false);
    if (labeledMarkers.isNotEmpty) {
      // Markers at the same spot would print their labels on top of each
      // other: stack each extra label one line lower.
      final labelRows = <String, int>{};
      await labelLayer.createMulti([
        for (final marker in labeledMarkers)
          PointAnnotationOptions(
            geometry: _point(marker.coordinate),
            textField: marker.label,
            textSize: 12,
            textOffset: [
              0,
              (marker.badge != null ? 1.85 : 1.6) +
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
            textHaloWidth: 1.8,
          ),
      ]);
    }

    if (fit) {
      await _fitCamera();
    }
  }

  Future<Uint8List> _pinBitmapFor({
    required String badge,
    required Color color,
    required bool highlighted,
  }) async {
    final cacheKey = '$badge|${color.toARGB32()}|$highlighted';
    final cached = _pinImageCache[cacheKey];
    if (cached != null) return cached;

    // Rendered at 2x pixel density (drawn at iconSize: 0.5) for razor-sharp
    // circular numbered badges matching Web's Coastal Heritage markers.
    final canvasSize = highlighted ? 84.0 : 68.0;
    final center = Offset(canvasSize / 2, canvasSize / 2);
    final circleRadius = highlighted ? 30.0 : 25.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    if (highlighted) {
      canvas.drawCircle(
        center,
        circleRadius + 9,
        Paint()..color = const Color(0x55174B4A),
      );
    }

    // Subtle elevation shadow under the pin.
    canvas.drawCircle(
      center.translate(0, 3),
      circleRadius + 1,
      Paint()
        ..color = const Color(0x3D000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Fill circle + crisp white border.
    canvas
      ..drawCircle(center, circleRadius, Paint()..color = color)
      ..drawCircle(
        center,
        circleRadius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5,
      );

    final textPainter = TextPainter(
      text: TextSpan(
        text: badge,
        style: TextStyle(
          color: Colors.white,
          fontSize: badge.length >= 2 ? 22 : 25,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(canvasSize.toInt(), canvasSize.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final bytes = data!.buffer.asUint8List();
    _pinImageCache[cacheKey] = bytes;
    return bytes;
  }

  static Point _point(NavigationCoordinate coordinate) =>
      Point(coordinates: Position(coordinate.longitude, coordinate.latitude));
}
