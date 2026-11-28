import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/navigation_location_tracker.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/live_offline_package_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_map.dart';
import 'package:trip_mate_mobile/features/traveler/resources/offline_ui_text.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';

class OfflineItineraryMapPage extends StatefulWidget {
  const OfflineItineraryMapPage({
    required this.itineraryId,
    this.repository,
    this.locationTracker,
    this.mapBuilder,
    super.key,
  });
  final int itineraryId;
  final OfflineTripRepository? repository;
  final NavigationLocationTracker? locationTracker;
  final Widget Function(BuildContext, OfflineTripManifest, bool showLocation)?
  mapBuilder;
  @override
  State<OfflineItineraryMapPage> createState() =>
      _OfflineItineraryMapPageState();
}

class _OfflineItineraryMapPageState extends State<OfflineItineraryMapPage> {
  bool _showLocation = false;
  bool _checkingLocation = false;
  String? _locationMessage;

  Future<void> _requestLocation() async {
    if (_checkingLocation) return;
    setState(() {
      _checkingLocation = true;
    });
    try {
      final tracker =
          widget.locationTracker ?? locateOptional<NavigationLocationTracker>();
      final access = tracker == null
          ? NavigationLocationAccess.denied
          : await tracker.ensureAccess();
      if (!mounted) return;
      setState(() {
        _showLocation = access == NavigationLocationAccess.granted;
        _locationMessage = _showLocation ? null : OfflineUiText.gpsDenied;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationMessage = OfflineUiText.gpsDenied;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingLocation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final repo = widget.repository ?? locateOptional<OfflineTripRepository>();
    if (repo == null) {
      return Scaffold(
        backgroundColor: c.canvas,
        appBar: const AppCoastalAppBar(title: 'Bản đồ ngoại tuyến'),
        body: const AppEmptyState(
          icon: Icons.map_outlined,
          title: OfflineUiText.loadError,
        ),
      );
    }
    return BlocProvider(
      create: (_) => LiveOfflinePackageCubit(
        repo,
        itineraryId: widget.itineraryId,
        networkInfo: locateOptional<NetworkInfo>(),
      )..load(),
      child: BlocBuilder<LiveOfflinePackageCubit, LiveOfflinePackageState>(
        builder: (context, state) {
          final c = context.tmColors;
          final manifest = state.manifest;
          final readable =
              manifest != null &&
              !manifest.locked &&
              manifest.mapResourcesAvailable;
          return Scaffold(
            backgroundColor: c.canvas,
            appBar: AppCoastalAppBar(
              title: 'Bản đồ ngoại tuyến',
              actions: [
                if (readable)
                  IconButton(
                    onPressed: _checkingLocation ? null : _requestLocation,
                    tooltip: 'Vị trí của tôi',
                    icon: const Icon(Icons.my_location),
                  ),
              ],
            ),
            body: state.isLoading
                ? Center(child: CircularProgressIndicator(color: c.brandTeal))
                : !readable
                ? AppEmptyState(
                    icon: manifest?.locked == true
                        ? Icons.lock_outline
                        : Icons.map_outlined,
                    title: manifest?.locked == true
                        ? OfflineUiText.locked
                        : state.error ?? OfflineUiText.missing,
                  )
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: c.tealSoftContainer,
                          border: Border(
                            bottom: BorderSide(color: c.borderSubtle),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.offline_bolt_outlined,
                              size: 16,
                              color: c.brandTeal,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                'Bản đồ chỉ dùng trong vùng đã tải. Tuyến đường được lưu sẵn; không tự tính lại đường khi mất mạng.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_locationMessage != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.xs,
                            AppSpacing.md,
                            AppSpacing.xs,
                          ),
                          child: AppAlert(
                            type: AppAlertType.warning,
                            message: _locationMessage!,
                          ),
                        ),
                      Expanded(
                        child:
                            widget.mapBuilder?.call(
                              context,
                              manifest,
                              _showLocation,
                            ) ??
                            TripMap(
                              key: ValueKey(
                                'offline-${manifest.generation}-$_showLocation',
                              ),
                              styleUri: manifest.styleUri,
                              initialFocus: offlineMapInitialFocus(manifest),
                              camera: TripMapCamera.fitMarkers,
                              showUserLocation: _showLocation,
                              mapWidgetKey: const ValueKey(
                                'offline-itinerary-map',
                              ),
                              markers: [
                                for (final poi in manifest.snapshot.pois)
                                  TripMapMarker(
                                    id: poi.id,
                                    coordinate: NavigationCoordinate(
                                      latitude: poi.latitude,
                                      longitude: poi.longitude,
                                    ),
                                    label: poi.name,
                                    color: c.brandTeal,
                                  ),
                              ],
                              lines: [
                                for (final route in manifest.snapshot.routes)
                                  TripMapLine(points: route.geometry),
                              ],
                            ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

NavigationCoordinate? offlineMapInitialFocus(OfflineTripManifest manifest) {
  final endpoint =
      manifest.snapshot.itinerary.startLocation ??
      manifest.snapshot.itinerary.endLocation;
  if (endpoint != null) {
    return NavigationCoordinate(
      latitude: endpoint.latitude,
      longitude: endpoint.longitude,
    );
  }
  if (manifest.snapshot.pois.isNotEmpty) {
    final poi = manifest.snapshot.pois.first;
    return NavigationCoordinate(
      latitude: poi.latitude,
      longitude: poi.longitude,
    );
  }
  for (final route in manifest.snapshot.routes) {
    if (route.geometry.isNotEmpty) {
      return route.geometry.first;
    }
  }
  return null;
}
