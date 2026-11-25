import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show MapboxStyles;
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_map.dart';

/// Mapbox map for UC-13: Coastal Teal route line with white road casing,
/// numbered circular stop pins, and the device location puck. The camera
/// follows the puck until the Traveler pans; [recenter] resumes following and
/// [fitAll] frames the whole route overview.
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
  final _mapKey = GlobalKey<TripMapState>();

  /// Resumes following the Traveler's position.
  void recenter() => _mapKey.currentState?.recenter();

  /// Frames all stops and the active route line.
  void fitAll() => unawaited(_mapKey.currentState?.fitAll());

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    return TripMap(
      key: _mapKey,
      styleUri: MapboxStyles.MAPBOX_STREETS,
      fitPadding: const EdgeInsets.fromLTRB(48, 190, 48, 280),
      markers: navigationMapMarkers(widget.items, widget.targetItemId),
      lines: [
        if (route != null && route.geometry.length >= 2)
          TripMapLine(
            points: route.geometry,
            color: CoastalPalette.light.primary,
            width: 6.5,
            opacity: 0.96,
            casingColor: Colors.white,
            casingWidth: 10,
          ),
      ],
      initialFocus: _initialFocus(),
    );
  }

  NavigationCoordinate? _initialFocus() {
    NavigationSessionItem? focus;
    for (final item in widget.items) {
      if (item.itemId == widget.targetItemId) focus = item;
    }
    focus ??= widget.items.isEmpty ? null : widget.items.first;
    return focus == null
        ? null
        : NavigationCoordinate(
            latitude: focus.latitude,
            longitude: focus.longitude,
          );
  }
}

/// Coastal Heritage navigation stop markers: numbered pins with emerald check
/// for reached stops and a highlighted deep-teal pin for the active target.
List<TripMapMarker> navigationMapMarkers(
  List<NavigationSessionItem> items,
  int? targetItemId,
) => [
  for (final item in items)
    TripMapMarker(
      id: item.itemId,
      coordinate: NavigationCoordinate(
        latitude: item.latitude,
        longitude: item.longitude,
      ),
      label: '${item.displayNumber}. ${item.poiName}',
      badge: item.isReached ? '✓' : '${item.displayNumber}',
      highlighted: item.itemId == targetItemId,
      radius: item.itemId == targetItemId ? 12 : 9,
      color: item.itemId == targetItemId
          ? CoastalPalette.light.primary
          : switch (item.status) {
              NavigationItemStatus.reached => CoastalPalette.light.success,
              NavigationItemStatus.skipped => const Color(0xFFD97706),
              NavigationItemStatus.pending => CoastalPalette.light.secondary,
            },
    ),
];
