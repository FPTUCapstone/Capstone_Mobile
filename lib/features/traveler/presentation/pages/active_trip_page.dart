import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/navigation_session_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/geo_distance.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/navigation_location_tracker.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/demo_navigation_session_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/mapbox_navigation_map.dart';
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
    this.sessionRepository,
    this.locationTracker,
    this.directionsRepository,
    this.useMapbox,
    this.isDemoMode = false,
  });

  final int itineraryId;
  final String? title;
  final ActiveTripCubit? cubit;
  final ItineraryRepository? repository;
  final NavigationSessionRepository? sessionRepository;
  final NavigationLocationTracker? locationTracker;
  final RouteDirectionsRepository? directionsRepository;

  /// Defaults to whether a Mapbox token is configured.
  final bool? useMapbox;
  final bool isDemoMode;

  @override
  State<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends State<ActiveTripPage> {
  final _mapKey = GlobalKey<MapboxNavigationMapState>();
  bool _isRerouteSheetOpen = false;
  bool _isArrivalDialogOpen = false;
  BuildContext? _arrivalDialogContext;
  bool _isCompletionShown = false;
  late bool _isLoadingMetadata;
  String? _metadataError;
  String? _resolvedTitle;

  /// Created once after metadata is resolved; closed with the page.
  ActiveTripCubit? _ownedCubit;

  late final bool _useMapbox =
      widget.useMapbox ??
      (locateOptional<AppConfig>()?.mapboxAccessToken != null);

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
      final repo = widget.repository ?? locateOptional<ItineraryRepository>();
      if (repo == null) {
        throw const FormatException('Itinerary service unavailable.');
      }
      final detail = await repo.getById(widget.itineraryId);
      if (!mounted) return;
      setState(() {
        _isLoadingMetadata = false;
        _resolvedTitle = detail.title ?? 'Trip #${widget.itineraryId}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMetadata = false;
        _metadataError = 'Trip information unavailable.';
      });
    }
  }

  ActiveTripCubit? _createCubit() {
    final sessionRepository =
        widget.sessionRepository ??
        (widget.isDemoMode
            ? DemoNavigationSessionRepository()
            : locateOptional<NavigationSessionRepository>());
    if (sessionRepository == null) return null;
    return ActiveTripCubit(
      itineraryId: widget.itineraryId,
      itineraryTitle: _resolvedTitle ?? 'Trip #${widget.itineraryId}',
      sessionRepository: sessionRepository,
      locationTracker:
          widget.locationTracker ??
          (widget.isDemoMode
              ? null
              : locateOptional<NavigationLocationTracker>()),
      directionsRepository:
          widget.directionsRepository ??
          (widget.isDemoMode
              ? null
              : locateOptional<RouteDirectionsRepository>()),
      itineraryRepository: widget.isDemoMode
          ? null
          : (widget.repository ?? locateOptional<ItineraryRepository>()),
      isDemoMode: widget.isDemoMode,
      networkInfo: widget.isDemoMode ? null : locateOptional<NetworkInfo>(),
    )..start();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMetadata) {
      return const _MessageScaffold(
        title: 'Loading trip...',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('Loading trip information...'),
          ],
        ),
      );
    }

    if (_metadataError != null) {
      return _ErrorScaffold(
        title: 'Unable to load trip',
        message: _metadataError!,
        detail: 'Could not load itinerary #${widget.itineraryId}.',
        onRetry: _fetchMetadata,
      );
    }

    final body = BlocBuilder<ActiveTripCubit, ActiveTripState>(
      buildWhen: (prev, curr) =>
          prev.loadStatus != curr.loadStatus ||
          prev.loadErrorMessage != curr.loadErrorMessage ||
          prev.conflictSession != curr.conflictSession ||
          prev.conflictSessionId != curr.conflictSessionId ||
          prev.isSubmitting != curr.isSubmitting,
      builder: (context, state) => switch (state.loadStatus) {
        ActiveTripLoadStatus.loading => const _MessageScaffold(
          title: 'Starting navigation...',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppSpacing.md),
              Text('Preparing your route...'),
            ],
          ),
        ),
        ActiveTripLoadStatus.failed => _ErrorScaffold(
          title: 'Unable to start navigation',
          message: state.loadErrorMessage ?? 'Navigation could not start.',
          onRetry: state.canRetryLoad
              ? () => context.read<ActiveTripCubit>().start()
              : null,
        ),
        ActiveTripLoadStatus.conflict => _ConflictView(
          session: state.conflictSession,
          isSubmitting: state.isSubmitting,
          onResume: state.conflictSession == null
              ? null
              : () => context.pushReplacement(
                  AppRoutes.activeTripLive(state.conflictSession!.itineraryId),
                ),
          onEndAndStart: () => _confirmEndConflict(context),
        ),
        ActiveTripLoadStatus.ready => _buildNavigation(context),
      },
    );

    final cubit = widget.cubit ?? (_ownedCubit ??= _createCubit());
    if (cubit == null) {
      return const _ErrorScaffold(
        title: 'Unable to start navigation',
        message: 'Navigation service unavailable.',
      );
    }
    return BlocProvider.value(value: cubit, child: _withListeners(body));
  }

  @override
  void dispose() {
    _ownedCubit?.close();
    super.dispose();
  }

  /// Mounted with the provider (not with the navigation shell) so messages
  /// emitted while the session loads, e.g. "Resumed", are not missed.
  Widget _withListeners(Widget child) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ActiveTripCubit, ActiveTripState>(
          listenWhen: (prev, curr) =>
              prev.isRerouteSheetVisible != curr.isRerouteSheetVisible,
          listener: _onRerouteVisibilityChanged,
        ),
        BlocListener<ActiveTripCubit, ActiveTripState>(
          listenWhen: (prev, curr) =>
              prev.arrivalPromptItemId != curr.arrivalPromptItemId &&
              curr.arrivalPromptItemId != null,
          listener: (context, state) => _showArrivalPrompt(context, state),
        ),
        BlocListener<ActiveTripCubit, ActiveTripState>(
          listenWhen: (prev, curr) =>
              prev.arrivalPromptItemId != null &&
              curr.arrivalPromptItemId == null,
          listener: (context, state) => _closeWithdrawnArrivalPrompt(),
        ),
        BlocListener<ActiveTripCubit, ActiveTripState>(
          listenWhen: (prev, curr) =>
              prev.feedback != curr.feedback && curr.feedback != null,
          listener: (context, state) {
            final feedback = state.feedback!;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(feedback.message),
                  backgroundColor: feedback.isError ? AppColors.error : null,
                  // Errors stay long enough to be read and retried.
                  duration: Duration(seconds: feedback.isError ? 8 : 3),
                  action: feedback.canRetry
                      ? SnackBarAction(
                          label: 'Retry',
                          textColor: Colors.white,
                          onPressed: context
                              .read<ActiveTripCubit>()
                              .retryLastAction,
                        )
                      : null,
                ),
              );
          },
        ),
        BlocListener<ActiveTripCubit, ActiveTripState>(
          listenWhen: (prev, curr) => !prev.isTerminal && curr.isTerminal,
          listener: _showCompletionDialog,
        ),
      ],
      child: child,
    );
  }

  Widget _buildNavigation(BuildContext context) {
    return BlocBuilder<ActiveTripCubit, ActiveTripState>(
      // Position, distance, and maneuver updates are rendered by dedicated
      // selectors so GPS ticks do not rebuild the whole shell.
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.session != curr.session ||
          prev.targetItemId != curr.targetItemId ||
          prev.route != curr.route ||
          prev.isGuidanceAvailable != curr.isGuidanceAvailable ||
          prev.isSubmitting != curr.isSubmitting ||
          prev.activeBannerAlert != curr.activeBannerAlert ||
          !listEquals(prev.alerts, curr.alerts) ||
          prev.itineraryTitle != curr.itineraryTitle ||
          prev.itineraryVersion != curr.itineraryVersion ||
          prev.isOnline != curr.isOnline ||
          prev.activeRerouteProposal != curr.activeRerouteProposal ||
          prev.isRerouteSheetVisible != curr.isRerouteSheetVisible ||
          prev.isDemoMode != curr.isDemoMode,
      builder: (context, state) {
        final cubit = context.read<ActiveTripCubit>();
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _useMapbox
                      ? MapboxNavigationMap(
                          key: _mapKey,
                          items: state.items,
                          targetItemId: state.targetItemId,
                          route: state.route,
                        )
                      : NavigationMapCanvas(
                          items: state.items,
                          targetItemId: state.targetItemId,
                          hasRerouteProposal: state.hasPendingRerouteProposal,
                          isDeviation:
                              state.status ==
                              ActiveTripStatus.navigationOffRouteDeviation,
                          showNotice: false,
                        ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TopHeaderBar(
                        title: state.itineraryTitle,
                        version: state.itineraryVersion,
                        isOnline: state.isOnline,
                        isDemoMode: state.isDemoMode,
                        onBack: () => Navigator.of(context).maybePop(),
                        onOpenDemoControls: () =>
                            _showDemoControls(context, cubit),
                      ),
                      if (!_useMapbox)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xs),
                          child: NavigationMapPreviewNotice(),
                        ),
                      _LocationNotice(status: state.status, cubit: cubit),
                      const _ManeuverBannerSelector(),
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
                // The map controls sit directly above the panel, whose
                // height changes with its content (e.g. the stop list).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          right: AppSpacing.md,
                          bottom: AppSpacing.sm,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_useMapbox) ...[
                              _FloatingMapButton(
                                icon: Icons.my_location_rounded,
                                tooltip: 'Recenter on my position',
                                onPressed: () =>
                                    _mapKey.currentState?.recenter(),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            _AlertsButton(
                              count: state.alerts.length,
                              onPressed: () => TripAlertsSheet.show(
                                context,
                                alerts: state.alerts,
                                onReviewReroute: () =>
                                    cubit.openRerouteProposal(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // The panel never covers more than part of the map (half
                      // of it in landscape); longer content scrolls inside.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              MediaQuery.sizeOf(context).height *
                              (MediaQuery.orientationOf(context) ==
                                      Orientation.landscape
                                  ? 0.5
                                  : 0.7),
                        ),
                        child: SingleChildScrollView(
                          child: _BottomTripPanel(
                            state: state,
                            onArrive: (item) =>
                                _confirmManualArrival(context, item),
                            onSkip: (item) => _confirmSkip(context, item),
                            onNavigateTo: (item) =>
                                cubit.selectTarget(item.itemId),
                            onDepart: () => cubit.depart(),
                            onFinish: () => _confirmFinish(context, state),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onRerouteVisibilityChanged(
    BuildContext context,
    ActiveTripState state,
  ) {
    if (!state.isRerouteSheetVisible) {
      _isRerouteSheetOpen = false;
      return;
    }
    if (state.activeRerouteProposal == null || _isRerouteSheetOpen) return;
    _isRerouteSheetOpen = true;
    final cubit = context.read<ActiveTripCubit>();
    RerouteProposalSheet.show(
      context,
      proposal: state.activeRerouteProposal!,
      onAccept: () {
        _isRerouteSheetOpen = false;
        cubit.acceptRerouteProposal();
      },
      onDecline: () {
        _isRerouteSheetOpen = false;
        cubit.declineRerouteProposal();
      },
      onClose: () {
        _isRerouteSheetOpen = false;
        cubit.closeRerouteProposalSheet();
      },
    );
  }

  Future<void> _showArrivalPrompt(
    BuildContext context,
    ActiveTripState state,
  ) async {
    final item = state.arrivalPromptItem;
    if (item == null || _isArrivalDialogOpen) return;
    _isArrivalDialogOpen = true;
    final cubit = context.read<ActiveTripCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      // Tapping outside must not count as "Not yet" (that hides the stop
      // until the Traveler walks away).
      barrierDismissible: false,
      builder: (dialogContext) {
        _arrivalDialogContext = dialogContext;
        return AlertDialog(
          icon: const Icon(Icons.place_rounded, color: AppColors.secondary),
          title: const Text('Have you arrived?'),
          content: Text('It looks like you are at ${item.poiName}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("Yes, I'm here"),
            ),
          ],
        );
      },
    );
    _isArrivalDialogOpen = false;
    _arrivalDialogContext = null;
    // null: the question was withdrawn because the Traveler left the stop.
    if (confirmed == null) return;
    if (confirmed) {
      await cubit.confirmArrival();
    } else {
      cubit.dismissArrivalPrompt();
    }
  }

  void _closeWithdrawnArrivalPrompt() {
    final dialogContext = _arrivalDialogContext;
    if (!_isArrivalDialogOpen || dialogContext == null) return;
    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
  }

  Future<void> _confirmManualArrival(
    BuildContext context,
    NavigationSessionItem item,
  ) async {
    final cubit = context.read<ActiveTripCubit>();
    final confirmed = await _confirm(
      context,
      icon: Icons.place_rounded,
      title: 'Mark as arrived?',
      message: 'Confirm that you are at ${item.poiName}.',
      confirmLabel: "I'm here",
    );
    if (confirmed) await cubit.reachItem(item.itemId);
  }

  Future<void> _confirmSkip(
    BuildContext context,
    NavigationSessionItem item,
  ) async {
    final cubit = context.read<ActiveTripCubit>();
    final confirmed = await _confirm(
      context,
      icon: Icons.redo_rounded,
      title: 'Skip this stop?',
      message:
          '${item.poiName} will be marked as skipped. You can still visit it later.'
          '${item.isMandatory ? '\n\nThis is a mandatory stop in your itinerary.' : ''}',
      confirmLabel: 'Skip stop',
      isDestructive: item.isMandatory,
    );
    if (confirmed) await cubit.skipItem(item.itemId);
  }

  Future<void> _confirmFinish(
    BuildContext context,
    ActiveTripState state,
  ) async {
    final cubit = context.read<ActiveTripCubit>();
    final notVisited = state.items.where((item) => item.isReachable).length;
    final confirmed = await _confirm(
      context,
      icon: Icons.flag_outlined,
      title: 'Finish this trip?',
      message: notVisited == 0
          ? 'All stops are done. Navigation will end.'
          : '$notVisited ${notVisited == 1 ? 'stop has' : 'stops have'} not been '
                'visited. Navigation will end and they will be recorded as not visited.',
      confirmLabel: 'Finish trip',
      cancelLabel: 'Continue trip',
      isDestructive: notVisited > 0,
    );
    if (confirmed) await cubit.finish();
  }

  Future<void> _confirmEndConflict(BuildContext context) async {
    final cubit = context.read<ActiveTripCubit>();
    final confirmed = await _confirm(
      context,
      icon: Icons.flag_outlined,
      title: 'End the other trip?',
      message:
          'Your other trip will be finished and navigation for this trip will start.',
      confirmLabel: 'End and start',
      isDestructive: true,
    );
    if (confirmed) await cubit.endConflictingSessionAndStart();
  }

  Future<bool> _confirm(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final cubit = context.read<ActiveTripCubit>()..pauseArrivalPrompts();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(icon, color: isDestructive ? AppColors.error : null),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    cubit.resumeArrivalPrompts();
    return result ?? false;
  }

  void _showCompletionDialog(BuildContext context, ActiveTripState state) {
    if (_isCompletionShown) return;
    _isCompletionShown = true;
    final session = state.session;
    final (title, icon) = switch (session?.completionReason) {
      NavigationCompletionReason.expired => (
        'Trip time ended',
        Icons.schedule_rounded,
      ),
      NavigationCompletionReason.travelerStopped => (
        'Navigation ended',
        Icons.flag_rounded,
      ),
      _ => ('Trip Completed!', Icons.celebration_rounded),
    };
    final summary = session == null
        ? 'Navigation session ended.'
        : 'You reached ${session.reachedCount} of ${session.items.length} stops'
              '${session.skippedCount > 0 ? ' and skipped ${session.skippedCount}' : ''}.';
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(icon, color: AppColors.success, size: 40),
        title: Text(title),
        content: Text('${state.itineraryTitle}: $summary'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // Popping (rather than replacing the stack) completes the pushes
              // that opened this trip, so My trips reloads and drops the
              // "Trip in progress" tag.
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.popUntil((route) => route.isFirst);
              } else {
                context.go('/traveler');
              }
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
                    Flexible(
                      child: Text(
                        'DEMO_ONLY Test Controls',
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
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

/// Straight-line distance under which a long road route gets a "you are close"
/// hint on the target card.
const _nearbyStraightLineMeters = 150.0;

/// Vietnam-time "HH:mm", with the date when it is not today (trips may cross
/// midnight).
String _formatTime(DateTime time) =>
    tripTimeLabel(time, tripStart: DateTime.now());

String _formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

String _formatDuration(double seconds) {
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60} h ${minutes % 60} min';
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({
    required this.title,
    required this.message,
    this.detail,
    this.onRetry,
  });

  final String title;
  final String message;
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _MessageScaffold(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (detail != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go back'),
              ),
              if (onRetry != null)
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConflictView extends StatelessWidget {
  const _ConflictView({
    required this.session,
    required this.isSubmitting,
    required this.onResume,
    required this.onEndAndStart,
  });

  /// Null when the Traveler can no longer access the other trip.
  final NavigationSession? session;
  final bool isSubmitting;
  final VoidCallback? onResume;
  final VoidCallback onEndAndStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final other = session;
    return _MessageScaffold(
      title: 'Trip in progress',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.route_rounded, size: 48, color: AppColors.primary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'You are already navigating another trip',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            other == null
                ? 'You no longer have access to that trip, but you can end it to start this one.'
                : 'Itinerary #${other.itineraryId} · started ${_formatTime(other.startedAt)} · '
                      '${other.reachedCount} of ${other.items.length} stops reached.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (onResume != null) ...[
            FilledButton(
              onPressed: isSubmitting ? null : onResume,
              child: const Text('Resume that trip'),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          OutlinedButton(
            onPressed: isSubmitting ? null : onEndAndStart,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('End it and start this trip'),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}

class _TopHeaderBar extends StatelessWidget {
  const _TopHeaderBar({
    required this.title,
    required this.version,
    required this.isOnline,
    required this.isDemoMode,
    required this.onBack,
    required this.onOpenDemoControls,
  });

  final String title;
  final int version;
  final bool isOnline;
  final bool isDemoMode;
  final VoidCallback onBack;
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
            tooltip: 'Leave navigation (trip stays in progress)',
            onPressed: onBack,
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

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({required this.status, required this.cubit});

  final ActiveTripStatus status;
  final ActiveTripCubit cubit;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      ActiveTripStatus.navigationPermissionDenied => _StateNoticeCard(
        icon: Icons.location_disabled_rounded,
        color: AppColors.error,
        title: 'Location permission required',
        message:
            'Allow location access so TripMate can guide you and detect arrivals.',
        actions: [
          TextButton(
            onPressed: cubit.openAppSettings,
            child: const Text('Open settings'),
          ),
          TextButton(
            onPressed: cubit.retryLocation,
            child: const Text('Try again'),
          ),
        ],
      ),
      ActiveTripStatus.navigationLocationServiceDisabled => _StateNoticeCard(
        icon: Icons.location_off_rounded,
        color: AppColors.warning,
        title: 'Location services are off',
        message: 'Turn on location services to continue navigation.',
        actions: [
          TextButton(
            onPressed: cubit.openLocationSettings,
            child: const Text('Turn on'),
          ),
          TextButton(
            onPressed: cubit.retryLocation,
            child: const Text('Try again'),
          ),
        ],
      ),
      ActiveTripStatus.navigationPositionUnavailable => const _StateNoticeCard(
        icon: Icons.gps_off_rounded,
        color: AppColors.warning,
        title: 'GPS position unavailable',
        message:
            'Waiting for reliable GPS signal. Navigation will resume automatically.',
      ),
      ActiveTripStatus.navigationAcquiringPosition => const _StateNoticeCard(
        icon: Icons.gps_fixed_rounded,
        color: AppColors.primary,
        title: 'Acquiring GPS position',
        message: 'Finding your location...',
      ),
      ActiveTripStatus.navigationPausedBattery => const _StateNoticeCard(
        icon: Icons.battery_saver_rounded,
        color: AppColors.warning,
        title: 'Navigation paused',
        message:
            'Battery saver has suspended background updates. Reconnect to resume.',
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ManeuverBannerSelector extends StatelessWidget {
  const _ManeuverBannerSelector();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ActiveTripCubit,
      ActiveTripState,
      (ActiveTripManeuver?, String?)
    >(
      selector: (state) => (state.currentManeuver, state.targetItem?.poiName),
      builder: (context, data) {
        final (maneuver, targetName) = data;
        if (maneuver == null) return const SizedBox.shrink();
        return _ManeuverBanner(
          maneuver: maneuver,
          targetName: targetName ?? 'Destination',
        );
      },
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
      liveRegion: true,
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
                      Expanded(
                        child: Text(
                          maneuver.instruction,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        _formatDistance(maneuver.distanceMeters.toDouble()),
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
                    'To $targetName',
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

class _BottomTripPanel extends StatefulWidget {
  const _BottomTripPanel({
    required this.state,
    required this.onArrive,
    required this.onSkip,
    required this.onNavigateTo,
    required this.onDepart,
    required this.onFinish,
  });

  final ActiveTripState state;
  final ValueChanged<NavigationSessionItem> onArrive;
  final ValueChanged<NavigationSessionItem> onSkip;
  final ValueChanged<NavigationSessionItem> onNavigateTo;
  final VoidCallback onDepart;
  final VoidCallback onFinish;

  @override
  State<_BottomTripPanel> createState() => _BottomTripPanelState();
}

class _BottomTripPanelState extends State<_BottomTripPanel> {
  bool _showAllStops = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final session = state.session;
    final isBusy = state.isSubmitting || state.isTerminal;
    final target = state.targetItem;
    final exploring = state.exploringItem;

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
          Row(
            children: [
              Expanded(
                child: Text(
                  '${state.reachedWaypointsCount} of ${state.totalWaypointsCount} stops reached',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.ink,
                  ),
                ),
              ),
              _PhaseBadge(state: state),
            ],
          ),
          if (state.isSubmitting) ...[
            const SizedBox(height: AppSpacing.xs),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (state.isExploring && exploring != null)
            _ExploringCard(
              item: exploring,
              hasPendingItems: state.hasPendingItems,
              isBusy: isBusy,
              onDepart: widget.onDepart,
              onFinish: widget.onFinish,
            )
          else if (target != null)
            _TargetCard(
              item: target,
              isSuggested: target.itemId == session?.nextItemId,
              isGuidanceAvailable: state.isGuidanceAvailable,
              isBusy: isBusy,
              onArrive: () => widget.onArrive(target),
              onSkip: target.status == NavigationItemStatus.pending
                  ? () => widget.onSkip(target)
                  : null,
            )
          else if (!state.isTerminal)
            _AllStopsDoneCard(
              skippedCount: session?.skippedCount ?? 0,
              isBusy: isBusy,
              onFinish: widget.onFinish,
            ),
          if (_showAllStops) ...[
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: state.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = state.items[index];
                  return _StopTile(
                    item: item,
                    isTarget: item.itemId == state.targetItemId,
                    isSuggested: item.itemId == session?.nextItemId,
                    isExploringHere: item.itemId == exploring?.itemId,
                    isBusy: isBusy,
                    onNavigateTo: () => widget.onNavigateTo(item),
                    onSkip: () => widget.onSkip(item),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
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
                  key: const Key('finish_trip_button'),
                  onPressed: isBusy ? null : widget.onFinish,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Finish trip'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhaseBadge extends StatelessWidget {
  const _PhaseBadge({required this.state});

  final ActiveTripState state;

  @override
  Widget build(BuildContext context) {
    if (state.isExploring) {
      return const StatusBadge(label: 'Exploring', type: StatusBadgeType.info);
    }
    if (state.status == ActiveTripStatus.navigationOffRouteDeviation) {
      return const StatusBadge(
        label: 'Off route',
        type: StatusBadgeType.warning,
      );
    }
    if (state.isTerminal) {
      return const StatusBadge(label: 'Ended', type: StatusBadgeType.neutral);
    }
    return const StatusBadge(
      label: 'Navigating',
      type: StatusBadgeType.success,
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.item,
    required this.isSuggested,
    required this.isGuidanceAvailable,
    required this.isBusy,
    required this.onArrive,
    required this.onSkip,
  });

  final NavigationSessionItem item;
  final bool isSuggested;
  final bool isGuidanceAvailable;
  final bool isBusy;
  final VoidCallback onArrive;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return _StopCard(
      leading: '${item.displayNumber}',
      leadingColor: AppColors.secondary,
      title: item.poiName,
      tags: [
        if (isSuggested) 'Suggested next',
        if (item.isMandatory) 'Mandatory',
        if (item.status == NavigationItemStatus.skipped) 'Skipped earlier',
      ],
      details: [
        BlocSelector<
          ActiveTripCubit,
          ActiveTripState,
          (double?, double?, double?, double?)
        >(
          selector: (state) => (
            state.distanceToTargetMeters,
            state.remainingDurationSeconds,
            state.currentLatitude,
            state.currentLongitude,
          ),
          builder: (context, metrics) {
            final (distance, duration, latitude, longitude) = metrics;
            final parts = [
              if (distance != null)
                '${_formatDistance(distance)}${isGuidanceAvailable ? '' : ' (straight line)'}',
              if (duration != null) _formatDuration(duration),
              'Planned ${_formatTime(item.plannedArrival)}',
            ];
            final straight = latitude == null || longitude == null
                ? null
                : distanceMeters(
                    NavigationCoordinate(
                      latitude: latitude,
                      longitude: longitude,
                    ),
                    NavigationCoordinate(
                      latitude: item.latitude,
                      longitude: item.longitude,
                    ),
                  );
            // The road route can be long even when the stop is just across a
            // block (dead-end lanes, one-way streets): say so.
            final isCloseButFarByRoad =
                isGuidanceAvailable &&
                straight != null &&
                distance != null &&
                straight <= _nearbyStraightLineMeters &&
                distance >= straight * 3;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parts.join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                if (isCloseButFarByRoad)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      straight < 20
                          ? 'You seem to be right at this stop. Tap '
                                '"I have arrived" to confirm.'
                          : 'Only ${straight.round()} m away in a straight '
                                'line. Tap "I have arrived" if you are already '
                                'there.',
                      key: const Key('nearby_stop_hint'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
      actions: [
        if (onSkip != null)
          Expanded(
            child: TextButton(
              key: const Key('skip_target_button'),
              onPressed: isBusy ? null : onSkip,
              child: const Text('Skip'),
            ),
          ),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            key: const Key('manual_arrived_button'),
            onPressed: isBusy ? null : onArrive,
            icon: const Icon(Icons.place_rounded, size: 18),
            label: const Text('I have arrived'),
          ),
        ),
      ],
    );
  }
}

class _ExploringCard extends StatelessWidget {
  const _ExploringCard({
    required this.item,
    required this.hasPendingItems,
    required this.isBusy,
    required this.onDepart,
    required this.onFinish,
  });

  final NavigationSessionItem item;
  final bool hasPendingItems;
  final bool isBusy;
  final VoidCallback onDepart;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return _StopCard(
      leading: '${item.displayNumber}',
      leadingColor: AppColors.success,
      title: 'You are at ${item.poiName}',
      tags: const [],
      details: [
        Text(
          'Planned departure ${_formatTime(item.plannedDeparture)}',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
      actions: [
        Expanded(
          child: hasPendingItems
              ? FilledButton.icon(
                  key: const Key('depart_button'),
                  onPressed: isBusy ? null : onDepart,
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Continue to next stop'),
                )
              : FilledButton.icon(
                  key: const Key('exploring_finish_button'),
                  onPressed: isBusy ? null : onFinish,
                  icon: const Icon(Icons.flag_rounded, size: 18),
                  label: const Text('Finish trip'),
                ),
        ),
      ],
    );
  }
}

class _AllStopsDoneCard extends StatelessWidget {
  const _AllStopsDoneCard({
    required this.skippedCount,
    required this.isBusy,
    required this.onFinish,
  });

  final int skippedCount;
  final bool isBusy;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return _StopCard(
      leading: '✓',
      leadingColor: AppColors.success,
      title: skippedCount == 0 ? 'All stops visited' : 'No stops left to visit',
      tags: const [],
      details: [
        Text(
          skippedCount == 0
              ? 'Finish the trip when you are ready.'
              : '$skippedCount skipped ${skippedCount == 1 ? 'stop' : 'stops'} '
                    'can still be visited from the stop list.',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
      actions: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isBusy ? null : onFinish,
            icon: const Icon(Icons.flag_rounded, size: 18),
            label: const Text('Finish trip'),
          ),
        ),
      ],
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.leading,
    required this.leadingColor,
    required this.title,
    required this.tags,
    required this.details,
    required this.actions,
  });

  final String leading;
  final Color leadingColor;
  final String title;
  final List<String> tags;
  final List<Widget> details;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: leadingColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    leading,
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
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: AppSpacing.xxs,
                        runSpacing: 2,
                        children: [
                          for (final tag in tags)
                            StatusBadge(
                              label: tag,
                              type: tag == 'Mandatory'
                                  ? StatusBadgeType.warning
                                  : StatusBadgeType.info,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 2),
                    ...details,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(children: actions),
        ],
      ),
    );
  }
}

enum _StopAction { navigateHere, skip }

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.item,
    required this.isTarget,
    required this.isSuggested,
    required this.isExploringHere,
    required this.isBusy,
    required this.onNavigateTo,
    required this.onSkip,
  });

  final NavigationSessionItem item;
  final bool isTarget;
  final bool isSuggested;
  final bool isExploringHere;
  final bool isBusy;
  final VoidCallback onNavigateTo;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final (statusIcon, statusLabel, statusColor) = switch (item.status) {
      NavigationItemStatus.reached => (
        Icons.check_circle_rounded,
        'Reached ${item.reachedAt == null ? '' : _formatTime(item.reachedAt!)}'
            .trim(),
        AppColors.success,
      ),
      NavigationItemStatus.skipped => (
        Icons.redo_rounded,
        'Skipped',
        AppColors.warning,
      ),
      NavigationItemStatus.pending => (
        Icons.radio_button_unchecked_rounded,
        'Planned ${_formatTime(item.plannedArrival)}',
        AppColors.muted,
      ),
    };
    final notes = [
      statusLabel,
      if (isExploringHere) 'You are here',
      if (isTarget && !isExploringHere) 'Heading here',
      if (isSuggested && !isTarget) 'Suggested next',
      if (item.isMandatory) 'Mandatory',
    ];
    final canNavigate = item.isReachable && !isTarget;
    final canSkip = item.status == NavigationItemStatus.pending;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 13,
        backgroundColor: isTarget ? AppColors.secondary : statusColor,
        child: Text(
          '${item.displayNumber}',
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
      ),
      title: Text(
        item.poiName,
        style: TextStyle(
          fontSize: 13,
          color: item.isReached ? AppColors.muted : AppColors.ink,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              notes.join(' · '),
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: (canNavigate || canSkip) && !isBusy
          ? PopupMenuButton<_StopAction>(
              key: Key('stop_actions_${item.itemId}'),
              tooltip: 'Stop actions',
              onSelected: (action) => switch (action) {
                _StopAction.navigateHere => onNavigateTo(),
                _StopAction.skip => onSkip(),
              },
              itemBuilder: (_) => [
                if (canNavigate)
                  const PopupMenuItem(
                    value: _StopAction.navigateHere,
                    child: Text('Navigate here'),
                  ),
                if (canSkip)
                  const PopupMenuItem(
                    value: _StopAction.skip,
                    child: Text('Skip this stop'),
                  ),
              ],
            )
          : null,
    );
  }
}

class _AlertsButton extends StatelessWidget {
  const _AlertsButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _FloatingMapButton(
          icon: Icons.notifications_active_outlined,
          tooltip: 'Trip alerts log',
          onPressed: onPressed,
        ),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$count',
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
    );
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
    this.actions = const [],
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final List<Widget> actions;

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
                if (actions.isNotEmpty)
                  Wrap(spacing: AppSpacing.xs, children: actions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
