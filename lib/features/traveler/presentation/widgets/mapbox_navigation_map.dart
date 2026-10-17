import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_map.dart';

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
  final _mapKey = GlobalKey<TripMapState>();

  /// Resumes following the Traveler's position.
  void recenter() => _mapKey.currentState?.recenter();

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    return TripMap(
      key: _mapKey,
      markers: navigationMapMarkers(widget.items, widget.targetItemId),
      lines: [
        if (route != null && route.geometry.length >= 2)
          TripMapLine(points: route.geometry),
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

/// Navigation stop markers: the target stop is larger and highlighted, the
/// others are coloured by progress.
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
      radius: item.itemId == targetItemId ? 11 : 8,
      color: item.itemId == targetItemId
          ? AppColors.secondary
          : switch (item.status) {
              NavigationItemStatus.reached => AppColors.muted,
              NavigationItemStatus.skipped => AppColors.warning,
              NavigationItemStatus.pending => AppColors.primary,
            },
    ),
];
