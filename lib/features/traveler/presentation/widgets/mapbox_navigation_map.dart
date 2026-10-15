import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';

/// Mapbox map for UC-13: route line to the target stop, stop markers with
/// labels, and the device location puck. The camera follows the puck until the
/// Traveler pans the map; [MapboxNavigationMapState.recenter] resumes following.
class MapboxNavigationMap extends StatefulWidget {
  const MapboxNavigationMap({
    super.key,
    required this.items,
    required this.targetItemId,
    required this.route,
  });

  final List<NavigationSessionItem> items;
  final int? targetItemId;
  final NavigationRoute? route;

  @override
  State<MapboxNavigationMap> createState() => MapboxNavigationMapState();
}

class MapboxNavigationMapState extends State<MapboxNavigationMap> {
  final _viewportController = ViewportController();
  MapboxMap? _map;
  PolylineAnnotationManager? _routeLayer;
  CircleAnnotationManager? _stopLayer;
  PointAnnotationManager? _labelLayer;
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

  /// The Traveler panned the map: stop following so that [recenter] is a real
  /// viewport change again (re-sending the same follow state is ignored).
  void _releaseCamera() {
    if (!_isFollowing) return;
    _isFollowing = false;
    _viewportController.moveTo(IdleViewportState(), transition: null);
  }

  @override
  void didUpdateWidget(MapboxNavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items ||
        oldWidget.targetItemId != widget.targetItemId ||
        oldWidget.route != widget.route) {
      _scheduleSync();
    }
  }

  @override
  void dispose() {
    unawaited(_panSubscription?.cancel());
    _viewportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focus = _initialFocus();
    return MapWidget(
      key: const ValueKey('mapbox-navigation-map'),
      viewport: CameraViewportState(
        center: focus == null
            ? null
            : Point(coordinates: Position(focus.longitude, focus.latitude)),
        zoom: 14,
      ),
      viewportController: _viewportController,
      onMapCreated: _onMapCreated,
    );
  }

  NavigationSessionItem? _initialFocus() {
    for (final item in widget.items) {
      if (item.itemId == widget.targetItemId) return item;
    }
    return widget.items.isEmpty ? null : widget.items.first;
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _panSubscription = map.gestures.pan.gestureEvents.listen(
      (_) => _releaseCamera(),
    );
    try {
      await map.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: true,
          puckBearingEnabled: true,
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
    } catch (_) {
      // The page may be leaving while the native map initialises; the map
      // then simply renders without overlays.
      return;
    }
    _scheduleSync();
    recenter();
  }

  void _scheduleSync() {
    if (_map == null) return;
    _syncQueue = _syncQueue.then((_) => _sync()).catchError((Object _) {
      // A failed redraw must not break navigation; the next update retries.
    });
  }

  Future<void> _sync() async {
    final routeLayer = _routeLayer;
    final stopLayer = _stopLayer;
    final labelLayer = _labelLayer;
    if (!mounted ||
        routeLayer == null ||
        stopLayer == null ||
        labelLayer == null) {
      return;
    }

    await routeLayer.deleteAll();
    final route = widget.route;
    if (route != null && route.geometry.length >= 2) {
      await routeLayer.create(
        PolylineAnnotationOptions(
          geometry: LineString(
            coordinates: [
              for (final point in route.geometry)
                Position(point.longitude, point.latitude),
            ],
          ),
          lineColor: AppColors.primary.toARGB32(),
          lineWidth: 6,
          lineOpacity: 0.85,
        ),
      );
    }

    await stopLayer.deleteAll();
    await labelLayer.deleteAll();
    if (widget.items.isEmpty) return;
    await stopLayer.createMulti([
      for (final item in widget.items)
        CircleAnnotationOptions(
          geometry: _point(item),
          circleRadius: item.itemId == widget.targetItemId ? 11 : 8,
          circleColor: _stopColor(item).toARGB32(),
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2,
        ),
    ]);
    // Stops at the same spot would print their labels on top of each other:
    // stack each extra label one line lower.
    final labelRows = <String, int>{};
    await labelLayer.createMulti([
      for (final item in widget.items)
        PointAnnotationOptions(
          geometry: _point(item),
          textField: '${item.displayNumber}. ${item.poiName}',
          textSize: 12,
          textOffset: [
            0,
            1.6 +
                1.3 *
                    (labelRows.update(
                          '${item.latitude},${item.longitude}',
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
  }

  Color _stopColor(NavigationSessionItem item) {
    if (item.itemId == widget.targetItemId) return AppColors.secondary;
    return switch (item.status) {
      NavigationItemStatus.reached => AppColors.muted,
      NavigationItemStatus.skipped => AppColors.warning,
      NavigationItemStatus.pending => AppColors.primary,
    };
  }

  static Point _point(NavigationSessionItem item) =>
      Point(coordinates: Position(item.longitude, item.latitude));
}
