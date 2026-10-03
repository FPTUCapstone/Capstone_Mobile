import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_waypoint.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/navigation_map_canvas.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/reroute_proposal_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_alert_banner.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_alerts_sheet.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

class ActiveTripPage extends StatefulWidget {
  const ActiveTripPage({
    super.key,
    required this.itineraryId,
    this.title,
    this.cubit,
    this.repository,
    this.isDemoMode = false,
  });

  final int itineraryId;
  final String? title;
  final ActiveTripCubit? cubit;
  final ItineraryRepository? repository;
  final bool isDemoMode;

  @override
  State<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends State<ActiveTripPage> {
  bool _isRerouteSheetOpen = false;
  late bool _isLoadingMetadata;
  String? _metadataError;
  String? _resolvedTitle;
  int? _resolvedVersion;

  @override
  void initState() {
    super.initState();
    final hasInitialTitle =
        widget.title != null && widget.title!.trim().isNotEmpty;
    if (widget.isDemoMode || hasInitialTitle || widget.cubit != null) {
      _isLoadingMetadata = false;
      _resolvedTitle =
          widget.title ?? (widget.isDemoMode ? 'Đà Nẵng Day Trip' : null);
    } else {
      _isLoadingMetadata = true;
      _fetchMetadata();
    }
  }

  Future<void> _fetchMetadata() async {
    setState(() {
      _isLoadingMetadata = true;
      _metadataError = null;
    });
    try {
      final repo =
          widget.repository ??
          (serviceLocator.isRegistered<ItineraryRepository>()
              ? serviceLocator<ItineraryRepository>()
              : null);
      if (repo == null) {
        throw const FormatException('Itinerary service unavailable.');
      }
      final detail = await repo.getById(widget.itineraryId);
      if (!mounted) return;
      setState(() {
        _isLoadingMetadata = false;
        _resolvedTitle = detail.title ?? 'Trip #${widget.itineraryId}';
        _resolvedVersion = detail.version;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMetadata = false;
        _metadataError = 'Trip information unavailable.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMetadata) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading trip...')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text('Loading trip information...'),
            ],
          ),
        ),
      );
    }

    if (_metadataError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Unable to load trip')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _metadataError!,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Could not load itinerary #${widget.itineraryId}.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Go back'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton(
                      onPressed: _fetchMetadata,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    final consumer = BlocConsumer<ActiveTripCubit, ActiveTripState>(
      listenWhen: (prev, curr) =>
          prev.isRerouteSheetVisible != curr.isRerouteSheetVisible ||
          prev.status != curr.status,
      listener: (context, state) {
        if (!state.isRerouteSheetVisible) {
          _isRerouteSheetOpen = false;
        } else if (state.activeRerouteProposal != null &&
            !_isRerouteSheetOpen) {
          _isRerouteSheetOpen = true;
          RerouteProposalSheet.show(
            context,
            proposal: state.activeRerouteProposal!,
            onAccept: () {
              _isRerouteSheetOpen = false;
              context.read<ActiveTripCubit>().acceptRerouteProposal();
            },
            onDecline: () {
              _isRerouteSheetOpen = false;
              context.read<ActiveTripCubit>().declineRerouteProposal();
            },
            onClose: () {
              _isRerouteSheetOpen = false;
              context.read<ActiveTripCubit>().closeRerouteProposalSheet();
            },
          );
        }
        if (state.status == ActiveTripStatus.navigationTripCompleted) {
          _showCompletionDialog(context, state);
        }
      },
      // Filters out coordinate-only GPS sensor emissions from invalidating
      // the static Active Trip presentation tree. High-frequency position updates
      // are decoupled from the static shell until native map SDK vector rendering
      // is integrated.
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.currentWaypointIndex != curr.currentWaypointIndex ||
          prev.currentManeuver != curr.currentManeuver ||
          prev.activeBannerAlert != curr.activeBannerAlert ||
          !listEquals(prev.alerts, curr.alerts) ||
          !listEquals(prev.waypoints, curr.waypoints) ||
          prev.itineraryTitle != curr.itineraryTitle ||
          prev.itineraryVersion != curr.itineraryVersion ||
          prev.isOnline != curr.isOnline ||
          prev.activeRerouteProposal != curr.activeRerouteProposal ||
          prev.isRerouteSheetVisible != curr.isRerouteSheetVisible ||
          prev.isDemoMode != curr.isDemoMode ||
          prev.statusMessage != curr.statusMessage,
      builder: (context, state) {
        final currentWaypoint = state.currentWaypoint;
        final cubit = context.read<ActiveTripCubit>();

        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Stack(
              children: [
                // 1. Center: Map Canvas Preview
                Positioned.fill(
                  child: NavigationMapCanvas(
                    waypoints: state.waypoints,
                    currentWaypointIndex: state.currentWaypointIndex,
                    hasRerouteProposal: state.hasPendingRerouteProposal,
                    isDeviation:
                        state.status ==
                        ActiveTripStatus.navigationOffRouteDeviation,
                  ),
                ),

                // 2. Top Bar & Instructions
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Header Row
                      _TopHeaderBar(
                        title: state.itineraryTitle,
                        version: state.itineraryVersion,
                        isOnline: state.isOnline,
                        isDemoMode: state.isDemoMode,
                        onExit: () => _confirmStopNavigation(context),
                        onOpenDemoControls: () =>
                            _showDemoControls(context, cubit),
                      ),

                      // System Guidance Banner / Notice (Permission, GPS, Paused)
                      if (state.status ==
                          ActiveTripStatus.navigationPermissionDenied)
                        _StateNoticeCard(
                          icon: Icons.location_disabled_rounded,
                          color: AppColors.error,
                          title: 'Location permission required',
                          message:
                              'Please enable location permissions in device Settings to navigate.',
                        )
                      else if (state.status ==
                          ActiveTripStatus.navigationPositionUnavailable)
                        _StateNoticeCard(
                          icon: Icons.gps_off_rounded,
                          color: AppColors.warning,
                          title: 'GPS position unavailable',
                          message:
                              'Waiting for reliable GPS signal. Navigation will resume automatically.',
                        )
                      else if (state.status ==
                          ActiveTripStatus.navigationAcquiringPosition)
                        _StateNoticeCard(
                          icon: Icons.gps_fixed_rounded,
                          color: AppColors.primary,
                          title: 'Acquiring GPS position',
                          message:
                              'Connecting to device sensors and route geometry...',
                        )
                      else if (state.status ==
                          ActiveTripStatus.navigationPausedBattery)
                        _StateNoticeCard(
                          icon: Icons.battery_saver_rounded,
                          color: AppColors.warning,
                          title: 'Navigation paused',
                          message:
                              'Battery saver has suspended background updates. Reconnect to resume.',
                        ),

                      // Turn-by-Turn Instruction Banner
                      if (state.currentManeuver != null)
                        _ManeuverBanner(
                          maneuver: state.currentManeuver!,
                          targetName: currentWaypoint?.name ?? 'Destination',
                        ),

                      // Real-Time Alert Banner (UC-14)
                      if (state.activeBannerAlert != null)
                        TripAlertBanner(
                          alert: state.activeBannerAlert!,
                          onDismiss: () => cubit.dismissBannerAlert(
                            state.activeBannerAlert!.id,
                          ),
                          onReviewReroute:
                              state.activeBannerAlert!.rerouteProposalAvailable
                              ? () => cubit.openRerouteProposal()
                              : null,
                        ),
                    ],
                  ),
                ),

                // 3. Floating Quick Action Controls (Right Column)
                Positioned(
                  right: AppSpacing.md,
                  bottom: 210,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Recenter Control
                      _FloatingMapButton(
                        icon: Icons.my_location_rounded,
                        tooltip: 'Recenter on my position',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Camera centered on current position',
                              ),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Alerts History Trigger (UC-14)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _FloatingMapButton(
                            icon: Icons.notifications_active_outlined,
                            tooltip: 'Trip alerts log',
                            onPressed: () {
                              TripAlertsSheet.show(
                                context,
                                alerts: state.alerts,
                                onReviewReroute: () =>
                                    cubit.openRerouteProposal(),
                              );
                            },
                          ),
                          if (state.alerts.isNotEmpty)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  '${state.alerts.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 4. Bottom Contextual Trip Panel
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomWaypointPanel(
                    state: state,
                    currentWaypoint: currentWaypoint,
                    onStopNavigation: () => _confirmStopNavigation(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (widget.cubit != null) {
      return BlocProvider.value(value: widget.cubit!, child: consumer);
    }

    return BlocProvider(
      create: (_) => ActiveTripCubit(
        itineraryId: widget.itineraryId,
        itineraryTitle: _resolvedTitle ?? 'Trip #${widget.itineraryId}',
        itineraryVersion: _resolvedVersion ?? 1,
        isDemoMode: widget.isDemoMode,
      ),
      child: consumer,
    );
  }

  void _confirmStopNavigation(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.flag_outlined, color: AppColors.error),
        title: const Text('Complete this trip?'),
        content: const Text(
          'Are you sure you want to complete this trip? Tracking will stop and trip summary will be saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continue Trip'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
              context.read<ActiveTripCubit>().stopNavigation();
            },
            child: const Text('Complete & Exit'),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog(BuildContext context, ActiveTripState state) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.celebration_rounded,
          color: AppColors.success,
          size: 40,
        ),
        title: const Text('Trip Completed!'),
        content: Text(
          'Congratulations on completing ${state.itineraryTitle}! All ${state.totalWaypointsCount} scheduled stops were visited.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/traveler');
            },
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  void _showDemoControls(BuildContext context, ActiveTripCubit cubit) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.bug_report_outlined,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'DEMO_ONLY Test Controls',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                const Text(
                  'These controls simulate GPS and system events for visual testing and review.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const Divider(height: 20),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Simulate Stop Arrival'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        cubit.demoSimulateArrivalAtNextStop();
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.cloud_outlined, size: 16),
                      label: const Text('Trigger Weather Disruption'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        cubit.demoSimulateWeatherDisruption();
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.alt_route, size: 16),
                      label: const Text('Simulate Off-Route (>500m)'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        cubit.demoSimulateRouteDeviation();
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.gps_not_fixed, size: 16),
                      label: const Text('Toggle GPS Acquiring'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        cubit.demoSimulateGpsAcquiring();
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.gps_off, size: 16),
                      label: const Text('Simulate GPS Lost'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        cubit.demoSimulateGpsLost();
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.location_disabled, size: 16),
                      label: const Text('Simulate Permission Denied'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        cubit.demoSimulatePermissionDenied();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────── Subwidgets ────────────────────────────── //

class _TopHeaderBar extends StatelessWidget {
  const _TopHeaderBar({
    required this.title,
    required this.version,
    required this.isOnline,
    required this.isDemoMode,
    required this.onExit,
    required this.onOpenDemoControls,
  });

  final String title;
  final int version;
  final bool isOnline;
  final bool isDemoMode;
  final VoidCallback onExit;
  final VoidCallback onOpenDemoControls;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      color: Colors.white.withValues(alpha: 0.95),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to trip summary',
            onPressed: onExit,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Active Itinerary · v$version',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          // Connection state pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0xFFE6F7F0)
                  : const Color(0xFFFEF3E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOnline ? Icons.wifi : Icons.wifi_off,
                  size: 12,
                  color: isOnline ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isOnline ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          // Demo Controls Action Button (only rendered when isDemoMode is true)
          if (isDemoMode) ...[
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: const Icon(
                Icons.build_circle_outlined,
                color: AppColors.warning,
              ),
              tooltip: 'DEMO_ONLY Controls',
              onPressed: onOpenDemoControls,
            ),
          ],
        ],
      ),
    );
  }
}

class _ManeuverBanner extends StatelessWidget {
  const _ManeuverBanner({required this.maneuver, required this.targetName});

  final ActiveTripManeuver maneuver;
  final String targetName;

  @override
  Widget build(BuildContext context) {
    final icon = switch (maneuver.direction) {
      ManeuverDirection.straight => Icons.straight_rounded,
      ManeuverDirection.turnLeft => Icons.turn_left_rounded,
      ManeuverDirection.turnRight => Icons.turn_right_rounded,
      ManeuverDirection.uTurn => Icons.u_turn_left_rounded,
      ManeuverDirection.arrive => Icons.place_rounded,
    };

    return Semantics(
      container: true,
      label: 'Next instruction: ${maneuver.instruction}',
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text(
                        'NEXT STOP',
                        style: TextStyle(
                          color: Color(0xFFB9D5FD),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${maneuver.distanceMeters} m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    targetName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    maneuver.instruction,
                    style: const TextStyle(
                      color: Color(0xFFEAF1FE),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomWaypointPanel extends StatefulWidget {
  const _BottomWaypointPanel({
    required this.state,
    required this.currentWaypoint,
    required this.onStopNavigation,
  });

  final ActiveTripState state;
  final ActiveTripWaypoint? currentWaypoint;
  final VoidCallback onStopNavigation;

  @override
  State<_BottomWaypointPanel> createState() => _BottomWaypointPanelState();
}

class _BottomWaypointPanelState extends State<_BottomWaypointPanel> {
  bool _showAllStops = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final currentWaypoint = widget.currentWaypoint;
    final reachedCount = state.reachedWaypointsCount;
    final totalCount = state.totalWaypointsCount;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag notch
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Header: Stops status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining stops · ${totalCount - reachedCount} of $totalCount',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.ink,
                ),
              ),
              StatusBadge(
                label:
                    state.status == ActiveTripStatus.navigationOffRouteDeviation
                    ? 'Off route'
                    : 'On schedule',
                type:
                    state.status == ActiveTripStatus.navigationOffRouteDeviation
                    ? StatusBadgeType.warning
                    : StatusBadgeType.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Active Waypoint Info Card
          if (currentWaypoint != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${currentWaypoint.orderIndex}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentWaypoint.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ETA ${_formatTime(currentWaypoint.plannedArrival)} · Stay ${currentWaypoint.stayDurationMinutes} min',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Collapsible all stops list
          if (_showAllStops) ...[
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: state.waypoints.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final wp = state.waypoints[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: wp.isReached
                          ? AppColors.muted
                          : (index == state.currentWaypointIndex
                                ? AppColors.secondary
                                : AppColors.primary),
                      child: Text(
                        '${wp.orderIndex}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    title: Text(
                      wp.name,
                      style: TextStyle(
                        fontSize: 13,
                        decoration: wp.isReached
                            ? TextDecoration.lineThrough
                            : null,
                        color: wp.isReached ? AppColors.muted : AppColors.ink,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _formatTime(wp.plannedArrival),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.sm),

          // Actions Row: Expand stops + Stop Navigation
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _showAllStops = !_showAllStops),
                  icon: Icon(
                    _showAllStops
                        ? Icons.keyboard_arrow_up
                        : Icons.format_list_bulleted,
                    size: 18,
                  ),
                  label: Text(_showAllStops ? 'Hide stops' : 'View all stops'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onStopNavigation,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Stop Trip'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _FloatingMapButton extends StatelessWidget {
  const _FloatingMapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shape: const CircleBorder(),
      color: Colors.white,
      child: IconButton(
        icon: Icon(icon, color: AppColors.ink),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class _StateNoticeCard extends StatelessWidget {
  const _StateNoticeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  message,
                  style: const TextStyle(fontSize: 11, color: AppColors.ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
