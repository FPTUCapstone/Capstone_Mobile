import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/app_initialization_status.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_state.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_image.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_status_and_rating.dart';

/// Real interactive Mapbox map for POI Explore (Screen #50 / UC-12).
///
/// Replaces the previous illustrative CustomPainter map with real Mapbox
/// vector tiles, interactive drag/pan/zoom gestures, live POI marker annotations,
/// marker selection, camera bounds framing, and location puck integration.
class PoiMapPreview extends StatefulWidget {
  const PoiMapPreview({
    required this.state,
    required this.cubit,
    this.useMapbox,
    super.key,
  });

  final PoiListState state;
  final PoiListCubit cubit;

  /// Optional override for testing environments without native platform views.
  final bool? useMapbox;

  @override
  State<PoiMapPreview> createState() => _PoiMapPreviewState();
}

class _PoiMapPreviewState extends State<PoiMapPreview> {
  static const double _minZoomForLabels = 12.2;

  final _viewportController = ViewportController();
  MapboxMap? _map;
  CircleAnnotationManager? _circleManager;
  PointAnnotationManager? _pointManager;
  Cancelable? _circleTapSub;
  Cancelable? _pointTapSub;
  StreamSubscription<Object?>? _panSub;
  Future<void> _syncQueue = Future.value();
  bool _hasInitialFramed = false;
  double _currentZoom = 10.0;

  void _handleCameraChange(CameraChangedEventData event) {
    final newZoom = event.cameraState.zoom;
    final wasShowingLabels = _currentZoom >= _minZoomForLabels;
    final isShowingLabels = newZoom >= _minZoomForLabels;
    _currentZoom = newZoom;
    if (wasShowingLabels != isShowingLabels) {
      _scheduleSync();
    }
  }

  bool get _isMapboxAvailable {
    if (widget.useMapbox != null) return widget.useMapbox!;
    if (kIsWeb) return false;
    // Check headless test environment
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    final config = locateOptional<AppConfig>();
    final token = config?.mapboxAccessToken;
    if (token == null || token.isEmpty) return false;
    final initStatus = locateOptional<AppInitializationStatus>();
    if (initStatus != null && !initStatus.isMapboxAvailable) return false;
    return true;
  }

  String? get _tokenConfigurationError {
    final config = locateOptional<AppConfig>();
    final token = config?.mapboxAccessToken;
    if (token == null || token.isEmpty) {
      return 'Chưa cấu hình MAPBOX_ACCESS_TOKEN trong tệp cấu hình môi trường.';
    }
    if (!token.startsWith('pk.')) {
      return 'Mã truy cập Mapbox không hợp lệ (cần bắt đầu bằng pk.).';
    }
    return null;
  }

  @override
  void didUpdateWidget(PoiMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isMapboxAvailable) return;

    final itemsChanged = !listEquals(oldWidget.state.items, widget.state.items);
    final selectedChanged =
        oldWidget.state.selectedPoiId != widget.state.selectedPoiId;

    if (itemsChanged || selectedChanged) {
      _scheduleSync(fit: itemsChanged, easeToSelected: selectedChanged);
    }
  }

  @override
  void dispose() {
    unawaited(_panSub?.cancel());
    _circleTapSub?.cancel();
    _pointTapSub?.cancel();
    _viewportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.items.isEmpty) {
      return _EmptyMap(onReset: widget.cubit.resetFilters);
    }

    if (!_isMapboxAvailable) {
      // Check test environment or explicit test override first
      if (widget.useMapbox == false ||
          (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))) {
        return _HeadlessMapFallback(state: widget.state, cubit: widget.cubit);
      }

      final tokenError = _tokenConfigurationError;
      if (tokenError != null) {
        return _MapboxUnavailableView(
          title: 'Bản đồ Mapbox chưa sẵn sàng',
          message: tokenError,
          onReset: widget.cubit.resetFilters,
        );
      }
      return _HeadlessMapFallback(state: widget.state, cubit: widget.cubit);
    }

    final validPois = widget.state.items.where(_isValidPoiCoordinate).toList();
    final firstPoi = validPois.isNotEmpty ? validPois.first : null;
    final initialCenter = firstPoi != null
        ? Point(coordinates: Position(firstPoi.longitude, firstPoi.latitude))
        : Point(coordinates: Position(108.2022, 16.0544)); // Da Nang center

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Native Mapbox Map
            Positioned.fill(
              child: MapWidget(
                key: const ValueKey('mapbox-poi-explore-map'),
                viewport: CameraViewportState(center: initialCenter, zoom: 12),
                viewportController: _viewportController,
                onMapCreated: _onMapCreated,
                onCameraChangeListener: _handleCameraChange,
              ),
            ),

            // Top Status Badge: Mapbox Active
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 9,
                          color: AppColors.freshGreen,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Bản đồ Mapbox',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Floating Location Button
            Positioned(
              right: 16,
              top: 68,
              child: Semantics(
                button: true,
                label: 'Dùng vị trí hiện tại',
                child: Material(
                  elevation: 3,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.line),
                  ),
                  child: IconButton(
                    constraints: const BoxConstraints.tightFor(
                      width: 46,
                      height: 46,
                    ),
                    onPressed: widget.state.isLocating
                        ? null
                        : _handleLocationRequest,
                    tooltip: 'Vị trí của tôi',
                    icon: widget.state.isLocating
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.secondary,
                            ),
                          )
                        : const Icon(
                            Icons.my_location_rounded,
                            color: AppColors.secondary,
                            size: 22,
                          ),
                  ),
                ),
              ),
            ),

            // Bottom Selected POI Preview Card
            if (widget.state.selectedPoi case final poi?)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.65,
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: _MapPreviewCard(
                        poi: poi,
                        onDetails: () =>
                            context.push(AppRoutes.poiDetail(poi.id)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _panSub = map.gestures.pan.gestureEvents.listen((_) {});

    try {
      await map.location.updateSettings(
        LocationComponentSettings(enabled: true, pulsingEnabled: true),
      );
      await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

      final circleManager = await map.annotations
          .createCircleAnnotationManager();
      final pointManager = await map.annotations.createPointAnnotationManager();

      if (!mounted) return;
      _circleManager = circleManager;
      _pointManager = pointManager;

      _circleTapSub = circleManager.tapEvents(
        onTap: (annotation) {
          final rawId = annotation.customData?['poiId'];
          final id = switch (rawId) {
            final num n => n.toInt(),
            final String s => int.tryParse(s),
            _ => null,
          };
          if (id != null) {
            widget.cubit.selectPoi(id);
          }
        },
      );
      _pointTapSub = pointManager.tapEvents(
        onTap: (annotation) {
          final rawId = annotation.customData?['poiId'];
          final id = switch (rawId) {
            final num n => n.toInt(),
            final String s => int.tryParse(s),
            _ => null,
          };
          if (id != null) {
            widget.cubit.selectPoi(id);
          }
        },
      );
    } catch (_) {
      return;
    }

    _scheduleSync(fit: !_hasInitialFramed);
    _hasInitialFramed = true;
  }

  void _scheduleSync({bool fit = false, bool easeToSelected = false}) {
    if (_map == null) return;
    _syncQueue = _syncQueue
        .then((_) => _syncMarkers(fit: fit, easeToSelected: easeToSelected))
        .catchError((Object _) {});
  }

  Future<void> _syncMarkers({
    required bool fit,
    bool easeToSelected = false,
  }) async {
    final map = _map;
    final circleManager = _circleManager;
    final pointManager = _pointManager;

    if (!mounted ||
        map == null ||
        circleManager == null ||
        pointManager == null) {
      return;
    }

    try {
      final camera = await map.getCameraState();
      _currentZoom = camera.zoom;
    } catch (_) {}

    await circleManager.deleteAll();
    await pointManager.deleteAll();

    final validPois = widget.state.items.where(_isValidPoiCoordinate).toList();
    if (validPois.isEmpty) return;

    final selectedId = widget.state.selectedPoiId;

    // Draw Circle Annotations (Markers)
    await circleManager.createMulti([
      for (final poi in validPois)
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(poi.longitude, poi.latitude)),
          circleRadius: poi.id == selectedId ? 11.0 : 8.0,
          circleColor:
              (poi.id == selectedId ? AppColors.secondary : AppColors.primary)
                  .toARGB32(),
          circleStrokeColor:
              (poi.id == selectedId ? AppColors.freshGreen : Colors.white)
                  .toARGB32(),
          circleStrokeWidth: poi.id == selectedId ? 3.5 : 2.0,
          customData: {'poiId': poi.id},
        ),
    ]);

    // Draw Point Annotations (POI Name Labels) ONLY when zoomed in sufficiently (>= _minZoomForLabels).
    // When zoomed out, labels are hidden to avoid overlapping/cluttering, while the clean circle
    // pins remain visible and clickable, and the bottom card displays the selected POI details.
    final showLabels = _currentZoom >= _minZoomForLabels;
    if (showLabels) {
      await pointManager.createMulti([
        for (final poi in validPois)
          PointAnnotationOptions(
            geometry: Point(coordinates: Position(poi.longitude, poi.latitude)),
            textField: poi.name,
            textSize: poi.id == selectedId ? 12.0 : 11.0,
            textOffset: [0, 1.8],
            textColor: AppColors.ink.toARGB32(),
            textHaloColor: Colors.white.toARGB32(),
            textHaloWidth: 1.5,
            customData: {'poiId': poi.id},
          ),
      ]);
    }

    if (easeToSelected && selectedId != null) {
      final selectedPoi = validPois
          .where((p) => p.id == selectedId)
          .firstOrNull;
      if (selectedPoi != null) {
        await map.easeTo(
          CameraOptions(
            center: Point(
              coordinates: Position(
                selectedPoi.longitude,
                selectedPoi.latitude,
              ),
            ),
            zoom: 14.0,
          ),
          MapAnimationOptions(duration: 500),
        );
        return;
      }
    }

    if (fit) {
      final camera = await map.cameraForCoordinatesPadding(
        [
          for (final p in validPois)
            Point(coordinates: Position(p.longitude, p.latitude)),
        ],
        CameraOptions(),
        MbxEdgeInsets(
          top: 90,
          left: 48,
          bottom: widget.state.selectedPoi != null ? 220 : 64,
          right: 48,
        ),
        15,
        null,
      );
      if (mounted) await map.setCamera(camera);
    }
  }

  Future<void> _handleLocationRequest() async {
    await widget.cubit.requestLocation();
    final lat = widget.state.query.originLatitude;
    final lng = widget.state.query.originLongitude;
    if (lat != null && lng != null && _map != null) {
      await _map!.easeTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: 14.5,
        ),
        MapAnimationOptions(duration: 600),
      );
    }
  }

  static bool _isValidPoiCoordinate(PoiSummary poi) {
    final lat = poi.latitude;
    final lng = poi.longitude;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat < -90.0 || lat > 90.0) return false;
    if (lng < -180.0 || lng > 180.0) return false;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Map Overlays and Supporting Views
// ─────────────────────────────────────────────────────────────────────────────

class _MapPreviewCard extends StatelessWidget {
  const _MapPreviewCard({required this.poi, required this.onDetails});

  final PoiSummary poi;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 300;
            final imageSize = isCompact ? 64.0 : 80.0;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox.square(
                    dimension: imageSize,
                    child: PoiImage(url: poi.thumbnailUrl),
                  ),
                ),
                SizedBox(width: isCompact ? 10 : 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ĐANG CHỌN',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        poi.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          PoiRating(
                            rating: poi.averageRating,
                            reviewCount: poi.reviewCount,
                          ),
                          if (poi.distanceKm != null)
                            Text(
                              '${poi.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          PoiOpenStatus(isOpen: poi.isOpenNow),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: onDetails,
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Xem chi tiết'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MapboxUnavailableView extends StatelessWidget {
  const _MapboxUnavailableView({
    required this.title,
    required this.message,
    required this.onReset,
  });

  final String title;
  final String message;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 56, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.line),
              ),
              child: const Text('Đặt lại bộ lọc'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMap extends StatelessWidget {
  const _EmptyMap({required this.onReset});
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.map_outlined,
              size: 56,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Không có địa điểm để hiển thị trên bản đồ.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onReset, child: const Text('Đặt lại')),
          ],
        ),
      ),
    );
  }
}

/// Fallback view for headless unit tests where native GL surfaces cannot initialize.
class _HeadlessMapFallback extends StatelessWidget {
  const _HeadlessMapFallback({required this.state, required this.cubit});

  final PoiListState state;
  final PoiListCubit cubit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final selectedPoi =
            state.selectedPoi ??
            (state.items.isNotEmpty ? state.items.first : null);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xFFE8ECEF),
                child: Center(
                  child: Text(
                    'Bản đồ minh họa vị trí',
                    style: TextStyle(color: AppColors.ink),
                  ),
                ),
              ),
            ),
            if (selectedPoi != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.65,
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: _MapPreviewCard(
                        poi: selectedPoi,
                        onDetails: () =>
                            context.push(AppRoutes.poiDetail(selectedPoi.id)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
