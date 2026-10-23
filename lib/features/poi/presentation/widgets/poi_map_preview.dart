import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_state.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_image.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_status_and_rating.dart';

/// Abstraction for Mapbox map interactions, enabling isolated unit testing
/// of camera motions, lifecycle, and annotation synchronization.
abstract class PoiMapController {
  Future<void> initOptionalSettings();
  Future<bool> initAnnotationManagers({
    required void Function(int poiId) onPoiSelected,
  });
  Future<void> syncMarkers({
    required List<PoiSummary> pois,
    required int? selectedId,
    required bool showLabels,
    required bool fit,
    required bool easeToSelected,
  });
  Future<void> easeToLocation(double latitude, double longitude);
  void dispose();
}

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
    this.controller,
    super.key,
  });

  final PoiListState state;
  final PoiListCubit cubit;

  /// Optional override for testing environments without native platform views.
  final bool? useMapbox;

  /// Optional injected controller for testing without native GL surfaces.
  final PoiMapController? controller;

  static bool isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat < -90.0 || lat > 90.0) return false;
    if (lng < -180.0 || lng > 180.0) return false;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return false;
    return true;
  }

  static bool isValidPoiCoordinate(PoiSummary poi) {
    return isValidCoordinate(poi.latitude, poi.longitude);
  }

  @override
  State<PoiMapPreview> createState() => _PoiMapPreviewState();
}

class _PoiMapPreviewState extends State<PoiMapPreview> {
  static const double _minZoomForLabels = 12.2;

  final _viewportController = ViewportController();
  PoiMapController? _controller;
  StreamSubscription<Object?>? _panSub;
  Future<void> _syncQueue = Future.value();
  bool _hasInitialFramed = false;
  double _currentZoom = 10.0;
  String? _annotationInitError;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller;
      _initController(_controller!);
    }
  }

  void _handleCameraChange(CameraChangedEventData event) {
    final newZoom = event.cameraState.zoom;
    final wasShowingLabels = _currentZoom >= _minZoomForLabels;
    final isShowingLabels = newZoom >= _minZoomForLabels;
    _currentZoom = newZoom;
    if (wasShowingLabels != isShowingLabels) {
      _scheduleSync();
    }
  }

  String? get _tokenConfigurationError {
    final config = locateOptional<AppConfig>();
    if (config == null) {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return null;
      }
      return 'Chưa cấu hình MAPBOX_ACCESS_TOKEN trong tệp cấu hình môi trường.';
    }
    final token = config.mapboxAccessToken;
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
    if (_controller == null) return;

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
    _controller?.dispose();
    _viewportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.items.isEmpty) {
      return _EmptyMap(onReset: widget.cubit.resetFilters);
    }

    if (widget.useMapbox == false) {
      return _HeadlessMapFallback(state: widget.state, cubit: widget.cubit);
    }

    if (widget.controller != null) {
      return _buildInteractiveMap(context, isMock: true);
    }

    final tokenError = _tokenConfigurationError;
    if (tokenError != null) {
      return _MapboxUnavailableView(
        title: 'Bản đồ Mapbox chưa sẵn sàng',
        message: tokenError,
        onReset: widget.cubit.resetFilters,
      );
    }

    if (kIsWeb ||
        (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST'))) {
      return _HeadlessMapFallback(state: widget.state, cubit: widget.cubit);
    }

    return _buildInteractiveMap(context, isMock: false);
  }

  Widget _buildInteractiveMap(BuildContext context, {required bool isMock}) {
    final validPois = widget.state.items
        .where(PoiMapPreview.isValidPoiCoordinate)
        .toList();
    final firstPoi = validPois.isNotEmpty ? validPois.first : null;
    final initialCenter = firstPoi != null
        ? Point(coordinates: Position(firstPoi.longitude, firstPoi.latitude))
        : Point(coordinates: Position(108.2022, 16.0544)); // Da Nang center

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Native Mapbox Map or Mock Surface
            Positioned.fill(
              child: isMock
                  ? const ColoredBox(
                      key: ValueKey('mapbox-poi-explore-map'),
                      color: Color(0xFFE8ECEF),
                    )
                  : MapWidget(
                      key: const ValueKey('mapbox-poi-explore-map'),
                      viewport: CameraViewportState(
                        center: initialCenter,
                        zoom: 12,
                      ),
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

            // Essential Annotation Manager Initialization Error Banner with Retry
            if (_annotationInitError case final errorMessage?)
              Positioned(
                top: 68,
                left: 16,
                right: 76,
                child: Card(
                  elevation: 4,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _retryAnnotationInit,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Thử lại'),
                        ),
                      ],
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
    unawaited(_panSub?.cancel());
    _panSub = map.gestures.pan.gestureEvents.listen((_) {});

    final controller = _RealMapboxController(map);
    _controller = controller;
    await _initController(controller);
  }

  Future<void> _initController(PoiMapController controller) async {
    try {
      await controller.initOptionalSettings();
    } catch (e) {
      debugPrint('[Mapbox] Optional settings failed during initialization: $e');
    }
    if (!mounted) return;

    final success = await controller.initAnnotationManagers(
      onPoiSelected: widget.cubit.selectPoi,
    );
    if (!mounted) return;

    if (!success) {
      setState(() {
        _annotationInitError = 'Không thể tải điểm đánh dấu trên bản đồ.';
      });
      return;
    }

    if (_annotationInitError != null) {
      setState(() {
        _annotationInitError = null;
      });
    }

    _scheduleSync(fit: !_hasInitialFramed);
    _hasInitialFramed = true;
  }

  Future<void> _retryAnnotationInit() async {
    final controller = _controller;
    if (controller == null || !mounted) return;

    setState(() {
      _annotationInitError = null;
    });

    final success = await controller.initAnnotationManagers(
      onPoiSelected: widget.cubit.selectPoi,
    );
    if (!mounted) return;

    if (!success) {
      setState(() {
        _annotationInitError = 'Không thể tải điểm đánh dấu trên bản đồ.';
      });
      return;
    }

    _scheduleSync(fit: !_hasInitialFramed);
    _hasInitialFramed = true;
  }

  void _scheduleSync({bool fit = false, bool easeToSelected = false}) {
    final controller = _controller;
    if (controller == null) return;

    final showLabels = _currentZoom >= _minZoomForLabels;
    _syncQueue = _syncQueue
        .then(
          (_) => controller.syncMarkers(
            pois: widget.state.items,
            selectedId: widget.state.selectedPoiId,
            showLabels: showLabels,
            fit: fit,
            easeToSelected: easeToSelected,
          ),
        )
        .catchError((Object _) {});
  }

  Future<void> _handleLocationRequest() async {
    await widget.cubit.requestLocation();
    if (!mounted) return;

    final latestState = widget.cubit.state;
    final lat = latestState.query.originLatitude;
    final lng = latestState.query.originLongitude;

    if (latestState.locationMessage == null &&
        PoiMapPreview.isValidCoordinate(lat, lng) &&
        _controller != null) {
      try {
        await _controller!.easeToLocation(lat!, lng!);
      } catch (_) {}
    }
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

/// Real implementation of [PoiMapController] wrapping native [MapboxMap].
class _RealMapboxController implements PoiMapController {
  _RealMapboxController(this._map);

  final MapboxMap _map;
  CircleAnnotationManager? _circleManager;
  PointAnnotationManager? _pointManager;
  Cancelable? _circleTapSub;
  Cancelable? _pointTapSub;

  @override
  Future<void> initOptionalSettings() async {
    try {
      await _map.location.updateSettings(
        LocationComponentSettings(enabled: true, pulsingEnabled: true),
      );
    } catch (e) {
      debugPrint('[Mapbox] Optional location component settings failed: $e');
    }

    try {
      await _map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    } catch (e) {
      debugPrint('[Mapbox] Optional scale bar settings failed: $e');
    }
  }

  @override
  Future<bool> initAnnotationManagers({
    required void Function(int poiId) onPoiSelected,
  }) async {
    _cleanupManagers();
    try {
      final circleManager = await _map.annotations
          .createCircleAnnotationManager();
      final pointManager = await _map.annotations
          .createPointAnnotationManager();

      _circleManager = circleManager;
      _pointManager = pointManager;

      _circleTapSub = circleManager.tapEvents(
        onTap: (annotation) {
          final id = _extractPoiId(annotation.customData);
          if (id != null) onPoiSelected(id);
        },
      );
      _pointTapSub = pointManager.tapEvents(
        onTap: (annotation) {
          final id = _extractPoiId(annotation.customData);
          if (id != null) onPoiSelected(id);
        },
      );
      return true;
    } catch (e) {
      debugPrint(
        '[Mapbox] Essential annotation managers failed to initialize: $e',
      );
      _cleanupManagers();
      return false;
    }
  }

  void _cleanupManagers() {
    _circleTapSub?.cancel();
    _circleTapSub = null;
    _pointTapSub?.cancel();
    _pointTapSub = null;
    _circleManager = null;
    _pointManager = null;
  }

  static int? _extractPoiId(Map<dynamic, dynamic>? customData) {
    final rawId = customData?['poiId'];
    return switch (rawId) {
      final num n => n.toInt(),
      final String s => int.tryParse(s),
      _ => null,
    };
  }

  @override
  Future<void> syncMarkers({
    required List<PoiSummary> pois,
    required int? selectedId,
    required bool showLabels,
    required bool fit,
    required bool easeToSelected,
  }) async {
    final circleManager = _circleManager;
    final pointManager = _pointManager;
    if (circleManager == null || pointManager == null) return;

    await circleManager.deleteAll();
    await pointManager.deleteAll();

    final validPois = pois.where(PoiMapPreview.isValidPoiCoordinate).toList();
    if (validPois.isEmpty) return;

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
        await _map.easeTo(
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
      final camera = await _map.cameraForCoordinatesPadding(
        [
          for (final p in validPois)
            Point(coordinates: Position(p.longitude, p.latitude)),
        ],
        CameraOptions(),
        MbxEdgeInsets(
          top: 90,
          left: 48,
          bottom: selectedId != null ? 220 : 64,
          right: 48,
        ),
        15,
        null,
      );
      await _map.setCamera(camera);
    }
  }

  @override
  Future<void> easeToLocation(double latitude, double longitude) async {
    await _map.easeTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: 14.5,
      ),
      MapAnimationOptions(duration: 600),
    );
  }

  @override
  void dispose() {
    _cleanupManagers();
  }
}
