import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/core/push/push_device_coordinator.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/navigation_session_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/recommendation_feedback_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/trip_alert_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/geo_distance.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/navigation_location_tracker.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/weather_advisory_session_store.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/demo_navigation_session_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/mapbox_navigation_map.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/navigation_map_canvas.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/reroute_proposal_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_alert_banner.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_alerts_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/weather_advisory_banner.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/resources/traveler_emergency_vi.dart';
import 'package:uuid/uuid.dart';

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
    this.feedbackRepository,
    this.useMapbox,
    this.isDemoMode = false,
    this.initialIncidentId,
  });

  final int itineraryId;
  final String? title;
  final ActiveTripCubit? cubit;
  final ItineraryRepository? repository;
  final NavigationSessionRepository? sessionRepository;
  final NavigationLocationTracker? locationTracker;
  final RouteDirectionsRepository? directionsRepository;

  /// Receives the thumbs of the completion modal; defaults to the registered
  /// repository. Without one the modal does not ask.
  final RecommendationFeedbackRepository? feedbackRepository;

  /// Defaults to whether a Mapbox token is configured.
  final bool? useMapbox;
  final bool isDemoMode;
  final int? initialIncidentId;

  @override
  State<ActiveTripPage> createState() => _ActiveTripPageState();
}

class _ActiveTripPageState extends State<ActiveTripPage>
    with WidgetsBindingObserver {
  final _mapKey = GlobalKey<MapboxNavigationMapState>();
  bool _isRerouteSheetOpen = false;
  bool _isArrivalDialogOpen = false;
  BuildContext? _arrivalDialogContext;
  bool _isCompletionShown = false;
  bool _didOpenInitialIncident = false;
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
    WidgetsBinding.instance.addObserver(this);
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
        throw const FormatException('Dịch vụ lịch trình tạm thời gián đoạn.');
      }
      final detail = await repo.getById(widget.itineraryId);
      if (!mounted) return;
      setState(() {
        _isLoadingMetadata = false;
        _resolvedTitle = detail.title ?? 'Chuyến đi #${widget.itineraryId}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMetadata = false;
        _metadataError = 'Không thể tải thông tin chuyến đi.';
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
      itineraryTitle: _resolvedTitle ?? 'Chuyến đi #${widget.itineraryId}',
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
      alertRepository: widget.isDemoMode
          ? null
          : locateOptional<TripAlertRepository>(),
      pushHints: widget.isDemoMode
          ? null
          : locateOptional<PushDeviceCoordinator>()?.hints,
      emergencyHints: widget.isDemoMode
          ? null
          : locateOptional<PushDeviceCoordinator>()?.emergencyHints,
      weatherAdvisoryStore: widget.isDemoMode
          ? null
          : locateOptional<WeatherAdvisorySessionStore>(),
    )..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final cubit = widget.cubit ?? _ownedCubit;
      unawaited(cubit?.refreshSession());
      unawaited(cubit?.refreshAlerts());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    if (_isLoadingMetadata) {
      return _MessageScaffold(
        title: 'Đang tải chuyến đi...',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: palette.primary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Đang tải thông tin lịch trình...',
              style: TextStyle(color: palette.secondary),
            ),
          ],
        ),
      );
    }

    if (_metadataError != null) {
      return _ErrorScaffold(
        title: 'Không thể tải chuyến đi',
        message: _metadataError!,
        detail: 'Không thể mở lịch trình #${widget.itineraryId}.',
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
        ActiveTripLoadStatus.loading => _MessageScaffold(
          title: 'Đang bắt đầu dẫn đường...',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: palette.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Đang chuẩn bị lộ trình của bạn...',
                style: TextStyle(color: palette.secondary),
              ),
            ],
          ),
        ),
        ActiveTripLoadStatus.failed => _ErrorScaffold(
          title: 'Không thể bắt đầu dẫn đường',
          message: state.loadErrorMessage ?? 'Không thể khởi chạy dẫn đường.',
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
        title: 'Không thể bắt đầu dẫn đường',
        message: 'Dịch vụ dẫn đường hiện không khả dụng.',
      );
    }
    return BlocProvider.value(value: cubit, child: _withListeners(body));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ownedCubit?.close();
    super.dispose();
  }

  /// Mounted with the provider (not with the navigation shell) so messages
  /// emitted while the session loads are not missed.
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
          listenWhen: (previous, current) => previous.alerts != current.alerts,
          listener: _openInitialIncident,
        ),
        BlocListener<ActiveTripCubit, ActiveTripState>(
          listenWhen: (prev, curr) =>
              prev.feedback != curr.feedback && curr.feedback != null,
          listener: (context, state) {
            final feedback = state.feedback!;
            final palette = CoastalPalette.of(context);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(feedback.message),
                  backgroundColor: feedback.isError
                      ? palette.error
                      : palette.ink,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  duration: Duration(seconds: feedback.isError ? 8 : 3),
                  action: feedback.canRetry
                      ? SnackBarAction(
                          label: 'Thử lại',
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

  Future<void> _openInitialIncident(
    BuildContext context,
    ActiveTripState state,
  ) async {
    final incidentId = widget.initialIncidentId;
    if (_didOpenInitialIncident || incidentId == null) return;
    final alert = state.alerts.cast<TripAlert?>().firstWhere(
      (item) => item?.id == incidentId.toString(),
      orElse: () => null,
    );
    if (alert == null) return;
    _didOpenInitialIncident = true;
    final cubit = context.read<ActiveTripCubit>();
    await cubit.acknowledgeAlert(alert);
    if (!context.mounted) return;
    await _openAlertsSheet(context, cubit, firstAlertId: alert.id);
  }

  Future<void> _openAlertsSheet(
    BuildContext context,
    ActiveTripCubit cubit, {
    String? firstAlertId,
  }) {
    return TripAlertsSheet.show(
      context,
      cubit: cubit,
      firstAlertId: firstAlertId,
      onOpenAlert: (item) => unawaited(cubit.acknowledgeAlert(item)),
      onConfirmArrival: (item) =>
          unawaited(_confirmAlertArrival(context, item)),
      onDepartStop: (_) => _departFromOverstay(context, cubit),
    );
  }

  void _departFromOverstay(BuildContext context, ActiveTripCubit cubit) {
    final current = cubit.state;
    if (current.hasPendingItems) {
      unawaited(cubit.depart());
    } else {
      _confirmFinish(context, current);
    }
  }

  Widget _buildNavigation(BuildContext context) {
    final palette = CoastalPalette.of(context);
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
          backgroundColor: palette.canvas,
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
                        reachedCount: state.reachedWaypointsCount,
                        totalCount: state.totalWaypointsCount,
                        isOnline: state.isOnline,
                        alertCount: state.alerts.length,
                        isDemoMode: state.isDemoMode,
                        onBack: () => Navigator.of(context).maybePop(),
                        onOpenAlerts: () => _openAlertsSheet(context, cubit),
                        onOpenDemoControls: () =>
                            _showDemoControls(context, cubit),
                      ),
                      if (!_useMapbox)
                        const Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xxs),
                          child: NavigationMapPreviewNotice(),
                        ),
                      _LocationNotice(status: state.status, cubit: cubit),
                      if (!state.isExploring) const _ManeuverBannerSelector(),
                      if (state.activeWeatherAdvisory != null)
                        WeatherAdvisoryBanner(
                          advisory: state.activeWeatherAdvisory!,
                          onDismiss: cubit.dismissWeatherAdvisory,
                        ),
                      if (state.activeBannerAlert != null)
                        TripAlertBanner(
                          alert: state.activeBannerAlert!,
                          onDismiss: () => cubit.dismissBannerAlert(
                            state.activeBannerAlert!.id,
                          ),
                          onOpen: () async {
                            final alert = state.activeBannerAlert!;
                            await cubit.acknowledgeAlert(alert);
                            if (!context.mounted) return;
                            await _openAlertsSheet(context, cubit);
                          },
                          onReviewReroute:
                              state
                                      .activeBannerAlert!
                                      .rerouteProposalAvailable &&
                                  state.activeRerouteProposal != null
                              ? () => cubit.openRerouteProposal()
                              : null,
                          onConfirmArrival:
                              state.activeBannerAlert!.type ==
                                      TripAlertType.delay &&
                                  !state.activeBannerAlert!.isOverstay
                              ? () => unawaited(
                                  _confirmAlertArrival(
                                    context,
                                    state.activeBannerAlert!,
                                  ),
                                )
                              : null,
                          onDepartStop:
                              state.activeBannerAlert!.isOverstay &&
                                  state.session?.isExploring == true
                              ? (state.hasPendingItems
                                    ? () => unawaited(cubit.depart())
                                    : () => _confirmFinish(context, state))
                              : null,
                          onSkipAffectedStop:
                              state.items.any(
                                (item) =>
                                    item.itemId ==
                                        state
                                            .activeBannerAlert!
                                            .affectedItemId &&
                                    item.status == NavigationItemStatus.pending,
                              )
                              ? () => unawaited(
                                  _confirmAlertSkip(
                                    context,
                                    state.activeBannerAlert!,
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),
                // Bottom dock stays compact because the full stop list opens in
                // a dedicated modal bottom sheet, keeping the map open and
                // guaranteeing floating map controls never collide with banners.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_useMapbox)
                        Padding(
                          padding: const EdgeInsets.only(
                            right: AppSpacing.md,
                            bottom: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _FloatingMapButton(
                                icon: Icons.open_in_full_rounded,
                                tooltip: 'Xem toàn tuyến',
                                onPressed: () => _mapKey.currentState?.fitAll(),
                              ),
                              const SizedBox(width: 8),
                              _FloatingMapButton(
                                icon: Icons.my_location_rounded,
                                tooltip: 'Định vị lại vị trí của tôi',
                                onPressed: () =>
                                    _mapKey.currentState?.recenter(),
                              ),
                            ],
                          ),
                        ),
                      _BottomTripPanel(
                        state: state,
                        onArrive: (item) =>
                            _confirmManualArrival(context, item),
                        onSkip: (item) => _confirmSkip(context, item),
                        onDepart: () => cubit.depart(),
                        onOpenStopsSheet: () => _StopsTimelineSheet.show(
                          context,
                          cubit: cubit,
                          onNavigateTo: (item) =>
                              cubit.selectTarget(item.itemId),
                          onSkip: (item) => _confirmSkip(context, item),
                          onFinish: () => _confirmFinish(context, cubit.state),
                        ),
                        onFinish: () => _confirmFinish(context, state),
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
    final palette = CoastalPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _arrivalDialogContext = dialogContext;
        return AlertDialog(
          backgroundColor: palette.canvas,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.softAccent,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.place_rounded, color: palette.primary, size: 26),
          ),
          title: Text(
            'Bạn đã đến nơi chưa?',
            style: TextStyle(
              fontFamily: AppTypography.displayFont,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          content: Text(
            'Có vẻ bạn đang ở ${item.poiName}.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.secondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Chưa đến', style: TextStyle(color: palette.ink)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                shape: const StadiumBorder(),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Đúng, tôi đã đến'),
            ),
          ],
        );
      },
    );
    _isArrivalDialogOpen = false;
    _arrivalDialogContext = null;
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
      title: 'Xác nhận đã đến?',
      message: 'Xác nhận bạn đang có mặt tại ${item.poiName}.',
      confirmLabel: 'Tôi đã đến',
    );
    if (confirmed) await cubit.reachItem(item.itemId);
  }

  Future<void> _confirmAlertArrival(
    BuildContext context,
    TripAlert alert,
  ) async {
    final itemId = alert.affectedItemId;
    if (itemId == null) return;
    final item = context
        .read<ActiveTripCubit>()
        .state
        .items
        .cast<NavigationSessionItem?>()
        .firstWhere(
          (candidate) => candidate?.itemId == itemId,
          orElse: () => null,
        );
    if (item != null) await _confirmManualArrival(context, item);
  }

  Future<void> _confirmSkip(
    BuildContext context,
    NavigationSessionItem item,
  ) async {
    final cubit = context.read<ActiveTripCubit>();
    final confirmed = await _confirm(
      context,
      icon: Icons.redo_rounded,
      title: 'Bỏ qua điểm dừng này?',
      message:
          '${item.poiName} sẽ được đánh dấu là đã bỏ qua. Bạn vẫn có thể ghé lại sau.'
          '${item.isMandatory ? '\n\nĐây là điểm bắt buộc trong lịch trình của bạn.' : ''}',
      confirmLabel: 'Bỏ qua điểm',
      isDestructive: item.isMandatory,
    );
    if (confirmed) await cubit.skipItem(item.itemId);
  }

  Future<void> _confirmAlertSkip(BuildContext context, TripAlert alert) async {
    final item = context
        .read<ActiveTripCubit>()
        .state
        .items
        .cast<NavigationSessionItem?>()
        .firstWhere(
          (candidate) =>
              candidate?.itemId == alert.affectedItemId &&
              candidate?.status == NavigationItemStatus.pending,
          orElse: () => null,
        );
    if (item != null) await _confirmSkip(context, item);
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
      title: 'Kết thúc chuyến đi?',
      message: notVisited == 0
          ? 'Tất cả điểm dừng đã hoàn tất. Phiên dẫn đường sẽ kết thúc.'
          : 'Còn $notVisited điểm dừng chưa ghé thăm. Dẫn đường sẽ kết thúc và các điểm này được ghi nhận là chưa đi.',
      confirmLabel: 'Kết thúc chuyến',
      cancelLabel: 'Tiếp tục chuyến',
      isDestructive: notVisited > 0,
    );
    if (confirmed) await cubit.finish();
  }

  Future<void> _confirmEndConflict(BuildContext context) async {
    final cubit = context.read<ActiveTripCubit>();
    final confirmed = await _confirm(
      context,
      icon: Icons.flag_outlined,
      title: 'Kết thúc chuyến kia?',
      message:
          'Chuyến đi đang mở trước đó sẽ được kết thúc để bắt đầu dẫn đường cho chuyến này.',
      confirmLabel: 'Kết thúc & bắt đầu',
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
    String cancelLabel = 'Hủy',
    bool isDestructive = false,
  }) async {
    final cubit = context.read<ActiveTripCubit>()..pauseArrivalPrompts();
    final palette = CoastalPalette.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.canvas,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDestructive ? palette.errorBg : palette.softAccent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isDestructive ? palette.error : palette.primary,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: AppTypography.displayFont,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.secondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel, style: TextStyle(color: palette.ink)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isDestructive ? palette.error : palette.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    cubit.resumeArrivalPrompts();
    return result ?? false;
  }

  /// Opens the booking's notice, over Trip History so Back stays useful. A
  /// session with no booking of its own has only Trip History to offer.
  void _showEmergencyStoppedDialog(
    BuildContext context,
    String title,
    int? bookingId,
  ) {
    final palette = CoastalPalette.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const Key('active-trip-emergency-stopped'),
          backgroundColor: palette.canvas,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Icon(
            Icons.warning_amber_rounded,
            color: palette.error,
            size: 40,
          ),
          title: const Text(TravelerEmergencyStringsVi.stoppedTitle),
          content: Text(TravelerEmergencyStringsVi.stoppedDialogMessage(title)),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go(AppRoutes.tripHistory);
                if (bookingId != null) {
                  unawaited(
                    context.push(AppRoutes.travelerEmergency(bookingId)),
                  );
                }
              },
              child: const Text(TravelerEmergencyStringsVi.viewSafetyNotice),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCompletionDialog(
    BuildContext context,
    ActiveTripState state,
  ) async {
    if (_isCompletionShown) return;
    _isCompletionShown = true;
    final session = state.session;
    if (session?.isInterrupted ?? false) {
      _showEmergencyStoppedDialog(
        context,
        state.itineraryTitle,
        session?.bookingId,
      );
      return;
    }
    final (title, icon) = switch (session?.completionReason) {
      NavigationCompletionReason.expired => (
        'Đã hết thời gian chuyến đi',
        Icons.schedule_rounded,
      ),
      NavigationCompletionReason.travelerStopped => (
        'Đã kết thúc dẫn đường',
        Icons.flag_rounded,
      ),
      _ => ('Hoàn thành chuyến đi!', Icons.celebration_rounded),
    };
    final elapsedMinutes = session == null
        ? 0
        : (session.endedAt ?? DateTime.now())
              .difference(session.startedAt)
              .inMinutes
              .clamp(0, 24 * 60);
    final elapsedLabel = elapsedMinutes < 60
        ? '$elapsedMinutes phút'
        : '${elapsedMinutes ~/ 60}g ${elapsedMinutes % 60}p';

    final feedbackRepository =
        widget.feedbackRepository ??
        (widget.isDemoMode
            ? null
            : locateOptional<RecommendationFeedbackRepository>());
    final reachedStops = feedbackRepository == null || session == null
        ? const <NavigationSessionItem>[]
        : session.items.where((item) => item.isReached).toList(growable: false);
    final answers = <int, bool>{};
    final palette = CoastalPalette.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        key: const Key('active_trip_completion_dialog'),
        backgroundColor: palette.canvas,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.84,
            maxWidth: 420,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: palette.softAccent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE8A435),
                        width: 2.5,
                      ),
                    ),
                    child: Icon(icon, color: palette.primary, size: 32),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(dialogContext).textTheme.titleLarge?.copyWith(
                    fontFamily: AppTypography.displayFont,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _friendlyTripTitle(state.itineraryTitle),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: palette.secondary),
                ),
                if (session != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _CompletionStatTile(
                          value:
                              '${session.reachedCount}/${session.items.length}',
                          label: 'Điểm đã đến',
                          valueColor: palette.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CompletionStatTile(
                          value: '${session.skippedCount}',
                          label: 'Đã bỏ qua',
                          valueColor: palette.warningText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CompletionStatTile(
                          value: elapsedLabel,
                          label: 'Thời gian đi',
                          valueColor: palette.ink,
                        ),
                      ),
                    ],
                  ),
                ],
                if (reachedStops.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: _StopThumbs(stops: reachedStops, answers: answers),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    final navigator = Navigator.of(context);
                    if (navigator.canPop()) {
                      navigator.popUntil((route) => route.isFirst);
                    } else {
                      context.go('/traveler');
                    }
                  },
                  child: const Text('Về trang chủ'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (feedbackRepository == null || session == null) return;
    for (final MapEntry(key: poiId, value: liked) in answers.entries) {
      feedbackRepository
          .sendStopFeedback(
            clientEventId: const Uuid().v4(),
            itineraryId: session.itineraryId,
            poiId: poiId,
            liked: liked,
          )
          .ignore();
    }
  }

  void _showDemoControls(BuildContext context, ActiveTripCubit cubit) {
    final palette = CoastalPalette.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                    Icon(Icons.bug_report_outlined, color: palette.warningText),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'DEMO_ONLY Test Controls',
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: palette.ink,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Công cụ giả lập GPS và sự kiện để kiểm thử trực quan.',
                  style: TextStyle(color: palette.secondary, fontSize: 12),
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

String _friendlyTripTitle(String raw) {
  const prefix = 'Generated itinerary - ';
  if (raw.startsWith(prefix)) {
    return 'Lịch trình · ${raw.substring(prefix.length)}';
  }
  return raw;
}

String _formatTime(DateTime time) =>
    tripTimeLabel(time, tripStart: DateTime.now());

String _formatDistance(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

String _formatDuration(double seconds) {
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return '$minutes phút';
  return '${minutes ~/ 60} giờ ${minutes % 60} phút';
}

class _CompletionStatTile extends StatelessWidget {
  const _CompletionStatTile({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: palette.secondary),
          ),
        ],
      ),
    );
  }
}

/// Optional thumbs up/down for each reached stop in the completion modal.
class _StopThumbs extends StatefulWidget {
  const _StopThumbs({required this.stops, required this.answers});

  final List<NavigationSessionItem> stops;
  final Map<int, bool> answers;

  @override
  State<_StopThumbs> createState() => _StopThumbsState();
}

class _StopThumbsState extends State<_StopThumbs> {
  void _toggle(int poiId, bool liked) => setState(() {
    if (widget.answers[poiId] == liked) {
      widget.answers.remove(poiId);
    } else {
      widget.answers[poiId] = liked;
    }
  });

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Trải nghiệm các điểm dừng? (tùy chọn)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: palette.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < widget.stops.length; i++) ...[
            if (i > 0) Divider(height: 12, color: palette.border),
            _buildRow(widget.stops[i], palette),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(NavigationSessionItem stop, CoastalPalette palette) {
    final liked = widget.answers[stop.poiId];
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: palette.success,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${stop.displayNumber}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            stop.poiName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: palette.ink,
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Thích ${stop.poiName}',
          onPressed: () => _toggle(stop.poiId, true),
          style: IconButton.styleFrom(
            backgroundColor: liked == true ? palette.primary : palette.canvas,
            foregroundColor: liked == true ? Colors.white : palette.secondary,
            side: BorderSide(
              color: liked == true ? palette.primary : palette.border,
            ),
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
          ),
          icon: Icon(
            liked == true ? Icons.thumb_up : Icons.thumb_up_outlined,
            size: 17,
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Không thích ${stop.poiName}',
          onPressed: () => _toggle(stop.poiId, false),
          style: IconButton.styleFrom(
            backgroundColor: liked == false ? palette.error : palette.canvas,
            foregroundColor: liked == false ? Colors.white : palette.secondary,
            side: BorderSide(
              color: liked == false ? palette.error : palette.border,
            ),
            minimumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
          ),
          icon: Icon(
            liked == false ? Icons.thumb_down : Icons.thumb_down_outlined,
            size: 17,
          ),
        ),
      ],
    );
  }
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.canvas,
        foregroundColor: palette.ink,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            fontFamily: AppTypography.displayFont,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
      ),
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
    final palette = CoastalPalette.of(context);
    final theme = Theme.of(context);
    return _MessageScaffold(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: palette.errorBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 34, color: palette.error),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: palette.ink,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          if (detail != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.secondary,
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.ink,
                  side: BorderSide(color: palette.border),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Quay lại'),
              ),
              if (onRetry != null)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onRetry,
                  child: const Text('Thử lại'),
                ),
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

  final NavigationSession? session;
  final bool isSubmitting;
  final VoidCallback? onResume;
  final VoidCallback onEndAndStart;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    final theme = Theme.of(context);
    final other = session;
    return _MessageScaffold(
      title: 'Đang có chuyến khác',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.softAccent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.route_rounded,
                size: 34,
                color: palette.primary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Bạn đang dẫn đường một chuyến đi khác',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            other == null
                ? 'Bạn không còn quyền truy cập chuyến đi đó, nhưng có thể kết thúc nó để bắt đầu chuyến này.'
                : 'Lịch trình #${other.itineraryId} · bắt đầu ${_formatTime(other.startedAt)} · '
                      'đã đến ${other.reachedCount}/${other.items.length} điểm.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: palette.secondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (onResume != null) ...[
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                minimumSize: const Size.fromHeight(48),
                shape: const StadiumBorder(),
              ),
              onPressed: isSubmitting ? null : onResume,
              child: const Text('Tiếp tục chuyến kia'),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          OutlinedButton(
            onPressed: isSubmitting ? null : onEndAndStart,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.error,
              side: BorderSide(color: palette.error),
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: const Text('Kết thúc chuyến kia & bắt đầu chuyến này'),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text('Quay lại', style: TextStyle(color: palette.ink)),
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
    required this.reachedCount,
    required this.totalCount,
    required this.isOnline,
    required this.alertCount,
    required this.isDemoMode,
    required this.onBack,
    required this.onOpenAlerts,
    required this.onOpenDemoControls,
  });

  final String title;
  final int version;
  final int reachedCount;
  final int totalCount;
  final bool isOnline;
  final int alertCount;
  final bool isDemoMode;
  final VoidCallback onBack;
  final VoidCallback onOpenAlerts;
  final VoidCallback onOpenDemoControls;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.ink.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: palette.canvas,
            shape: const CircleBorder(),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: palette.ink,
                size: 20,
              ),
              tooltip: 'Rời màn dẫn đường (chuyến vẫn đang chạy)',
              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
              padding: EdgeInsets.zero,
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _friendlyTripTitle(title),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: AppTypography.displayFont,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                    fontSize: 14.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  totalCount > 0
                      ? 'v$version · Đã đến $reachedCount/$totalCount điểm'
                      : 'Lịch trình đang chạy · v$version',
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOnline ? palette.softAccent : palette.warningBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isOnline ? palette.success : palette.warningText,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  isOnline ? 'Trực tuyến' : 'Ngoại tuyến',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isOnline ? palette.success : palette.warningText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _HeaderAlertsButton(count: alertCount, onPressed: onOpenAlerts),
          if (isDemoMode) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.build_circle_outlined,
                color: palette.warningText,
                size: 20,
              ),
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              padding: EdgeInsets.zero,
              tooltip: 'DEMO_ONLY Controls',
              onPressed: onOpenDemoControls,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderAlertsButton extends StatelessWidget {
  const _HeaderAlertsButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: palette.canvas,
          shape: const CircleBorder(),
          child: IconButton(
            icon: Icon(
              Icons.notifications_none_rounded,
              color: palette.ink,
              size: 20,
            ),
            tooltip: 'Cảnh báo chuyến đi',
            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
            padding: EdgeInsets.zero,
            onPressed: onPressed,
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: palette.error,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.surface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _LocationNotice extends StatelessWidget {
  const _LocationNotice({required this.status, required this.cubit});

  final ActiveTripStatus status;
  final ActiveTripCubit cubit;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    return switch (status) {
      ActiveTripStatus.navigationPermissionDenied => _StateNoticeCard(
        icon: Icons.location_disabled_rounded,
        color: palette.error,
        title: 'Cần quyền truy cập vị trí',
        message:
            'Hãy cấp quyền vị trí để TripMate dẫn đường và tự động nhận diện khi bạn đến điểm.',
        actions: [
          TextButton(
            onPressed: cubit.openAppSettings,
            child: const Text('Mở cài đặt'),
          ),
          TextButton(
            onPressed: cubit.retryLocation,
            child: const Text('Thử lại'),
          ),
        ],
      ),
      ActiveTripStatus.navigationLocationServiceDisabled => _StateNoticeCard(
        icon: Icons.location_off_rounded,
        color: palette.warningText,
        title: 'Dịch vụ vị trí đang tắt',
        message: 'Bật định vị GPS trên thiết bị để tiếp tục dẫn đường.',
        actions: [
          TextButton(
            onPressed: cubit.openLocationSettings,
            child: const Text('Bật định vị'),
          ),
          TextButton(
            onPressed: cubit.retryLocation,
            child: const Text('Thử lại'),
          ),
        ],
      ),
      ActiveTripStatus.navigationPositionUnavailable => _StateNoticeCard(
        icon: Icons.gps_off_rounded,
        color: palette.warningText,
        title: 'Không có tín hiệu GPS',
        message:
            'Đang chờ tín hiệu GPS ổn định. Dẫn đường sẽ tự động tiếp tục.',
      ),
      ActiveTripStatus.navigationAcquiringPosition => _StateNoticeCard(
        icon: Icons.gps_fixed_rounded,
        color: palette.primary,
        title: 'Đang xác định vị trí GPS',
        message: 'Đang tìm vị trí hiện tại của bạn...',
      ),
      ActiveTripStatus.navigationPausedBattery => _StateNoticeCard(
        icon: Icons.battery_saver_rounded,
        color: palette.warningText,
        title: 'Dẫn đường tạm dừng',
        message:
            'Chế độ tiết kiệm pin đã tạm ngưng cập nhật vị trí nền. Mở lại để tiếp tục.',
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
          targetName: targetName ?? 'Điểm đến',
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
    final palette = CoastalPalette.of(context);
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
      label: 'Chỉ dẫn tiếp theo: ${maneuver.instruction}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [palette.primary, palette.primaryHover],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: palette.primary.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDistance(maneuver.distanceMeters.toDouble()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    maneuver.instruction,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Đến $targetName',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
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

class _BottomTripPanel extends StatelessWidget {
  const _BottomTripPanel({
    required this.state,
    required this.onArrive,
    required this.onSkip,
    required this.onDepart,
    required this.onOpenStopsSheet,
    required this.onFinish,
  });

  final ActiveTripState state;
  final ValueChanged<NavigationSessionItem> onArrive;
  final ValueChanged<NavigationSessionItem> onSkip;
  final VoidCallback onDepart;
  final VoidCallback onOpenStopsSheet;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    final session = state.session;
    final isBusy = state.isSubmitting || state.isTerminal;
    final target = state.targetItem;
    final exploring = state.exploringItem;
    final total = state.totalWaypointsCount;
    final reached = state.reachedWaypointsCount;
    final progress = total > 0 ? (reached / total).clamp(0.0, 1.0) : 0.0;

    NavigationSessionItem? nextPending;
    if (session?.nextItemId != null) {
      for (final item in state.items) {
        if (item.itemId == session!.nextItemId) {
          nextPending = item;
          break;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: palette.ink.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$reached / $total điểm đã đến',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: palette.ink,
                  ),
                ),
              ),
              _PhaseBadge(state: state),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.isSubmitting ? null : progress,
              minHeight: 5,
              backgroundColor: palette.border.withValues(alpha: 0.65),
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 12),
          if (state.isExploring && exploring != null)
            _ExploringCard(
              item: exploring,
              nextStopName: nextPending?.poiName,
              hasPendingItems: state.hasPendingItems,
              isBusy: isBusy,
              onDepart: onDepart,
              onFinish: onFinish,
            )
          else if (target != null)
            _TargetCard(
              item: target,
              isSuggested: target.itemId == session?.nextItemId,
              isGuidanceAvailable: state.isGuidanceAvailable,
              isBusy: isBusy,
              onArrive: () => onArrive(target),
              onSkip: target.status == NavigationItemStatus.pending
                  ? () => onSkip(target)
                  : null,
            )
          else if (!state.isTerminal)
            _AllStopsDoneCard(
              skippedCount: session?.skippedCount ?? 0,
              isBusy: isBusy,
              onFinish: onFinish,
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  key: const Key('view_all_stops_button'),
                  onPressed: onOpenStopsSheet,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.ink,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  icon: Icon(
                    Icons.format_list_bulleted_rounded,
                    size: 19,
                    color: palette.primary,
                  ),
                  label: Text(
                    'Danh sách điểm (${state.items.length})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                key: const Key('finish_trip_button'),
                onPressed: isBusy ? null : onFinish,
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.error,
                  side: BorderSide(color: palette.error.withValues(alpha: 0.7)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                child: const Text('Kết thúc'),
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
    final palette = CoastalPalette.of(context);
    final (label, bg, fg) = state.isExploring
        ? ('Đang tham quan', palette.softAccent, palette.success)
        : state.status == ActiveTripStatus.navigationOffRouteDeviation
        ? ('Lệch tuyến', palette.warningBg, palette.warningText)
        : state.isTerminal
        ? (
            'Đã kết thúc',
            palette.border.withValues(alpha: 0.5),
            palette.secondary,
          )
        : ('Đang dẫn đường', palette.softAccent, palette.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CoastalPillTag extends StatelessWidget {
  const _CoastalPillTag({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
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
    final palette = CoastalPalette.of(context);
    return _StopCard(
      leading: '${item.displayNumber}',
      leadingColor: palette.primary,
      backgroundColor: palette.surface,
      borderColor: palette.border,
      title: item.poiName,
      tags: [
        if (isSuggested)
          _CoastalPillTag(
            label: 'Gợi ý tiếp theo',
            background: palette.softAccent,
            foreground: palette.primary,
          ),
        if (item.isMandatory)
          _CoastalPillTag(
            label: 'Bắt buộc',
            background: palette.warningBg,
            foreground: palette.warningText,
          ),
        if (item.status == NavigationItemStatus.skipped)
          _CoastalPillTag(
            label: 'Đã bỏ qua trước đó',
            background: palette.warningBg,
            foreground: palette.warningText,
          ),
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
                '${_formatDistance(distance)}${isGuidanceAvailable ? '' : ' (đường chim bay)'}',
              if (duration != null) _formatDuration(duration),
              'Dự kiến ${_formatTime(item.plannedArrival)}',
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
                  style: TextStyle(fontSize: 12, color: palette.secondary),
                ),
                if (isCloseButFarByRoad)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      straight < 20
                          ? 'Bạn đang ở ngay điểm này. Nhấn "Tôi đã đến" để xác nhận.'
                          : 'Chỉ cách ${straight.round()} m theo đường chim bay. Nhấn "Tôi đã đến" nếu bạn đã ở nơi.',
                      key: const Key('nearby_stop_hint'),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
      actions: [
        if (onSkip != null) ...[
          Expanded(
            child: OutlinedButton(
              key: const Key('skip_target_button'),
              onPressed: isBusy ? null : onSkip,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.ink,
                side: BorderSide(color: palette.border),
                backgroundColor: palette.canvas,
                minimumSize: const Size.fromHeight(44),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              child: const Text('Bỏ qua'),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            key: const Key('manual_arrived_button'),
            onPressed: isBusy ? null : onArrive,
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              minimumSize: const Size.fromHeight(44),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            icon: const Icon(Icons.place_rounded, size: 18),
            label: const Text('Tôi đã đến'),
          ),
        ),
      ],
    );
  }
}

class _ExploringCard extends StatelessWidget {
  const _ExploringCard({
    required this.item,
    required this.nextStopName,
    required this.hasPendingItems,
    required this.isBusy,
    required this.onDepart,
    required this.onFinish,
  });

  final NavigationSessionItem item;
  final String? nextStopName;
  final bool hasPendingItems;
  final bool isBusy;
  final VoidCallback onDepart;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    final departLabel = nextStopName != null && nextStopName!.isNotEmpty
        ? 'Tiếp tục đến $nextStopName'
        : 'Tiếp tục đến điểm tiếp theo';
    return _StopCard(
      leading: '✓ ${item.displayNumber}',
      leadingColor: palette.success,
      backgroundColor: palette.softAccent,
      borderColor: palette.success.withValues(alpha: 0.35),
      title: 'Bạn đang ở ${item.poiName}',
      tags: [
        if (item.isMandatory)
          _CoastalPillTag(
            label: 'Bắt buộc',
            background: palette.warningBg,
            foreground: palette.warningText,
          ),
      ],
      details: [
        Text(
          '${item.reachedAt != null ? 'Đã check-in ${_formatTime(item.reachedAt!)} · ' : ''}'
          'Dự kiến rời ${_formatTime(item.plannedDeparture)}',
          style: TextStyle(fontSize: 12, color: palette.secondary),
        ),
      ],
      actions: [
        Expanded(
          child: hasPendingItems
              ? FilledButton.icon(
                  key: const Key('depart_button'),
                  onPressed: isBusy ? null : onDepart,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    minimumSize: const Size.fromHeight(44),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(
                    departLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : FilledButton.icon(
                  key: const Key('exploring_finish_button'),
                  onPressed: isBusy ? null : onFinish,
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    minimumSize: const Size.fromHeight(44),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.flag_rounded, size: 18),
                  label: const Text('Kết thúc chuyến đi'),
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
    final palette = CoastalPalette.of(context);
    return _StopCard(
      leading: '✓',
      leadingColor: palette.success,
      backgroundColor: palette.softAccent,
      borderColor: palette.success.withValues(alpha: 0.35),
      title: skippedCount == 0
          ? 'Đã đến tất cả điểm dừng'
          : 'Không còn điểm dừng nào',
      tags: const [],
      details: [
        Text(
          skippedCount == 0
              ? 'Bạn có thể kết thúc chuyến đi bất cứ lúc nào.'
              : 'Còn $skippedCount điểm đã bỏ qua — bạn vẫn có thể chọn lại từ danh sách điểm.',
          style: TextStyle(fontSize: 12, color: palette.secondary),
        ),
      ],
      actions: [
        Expanded(
          child: FilledButton.icon(
            onPressed: isBusy ? null : onFinish,
            style: FilledButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.onPrimary,
              minimumSize: const Size.fromHeight(44),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.flag_rounded, size: 18),
            label: const Text('Kết thúc chuyến đi'),
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
    required this.backgroundColor,
    required this.borderColor,
    required this.title,
    required this.tags,
    required this.details,
    required this.actions,
  });

  final String leading;
  final Color leadingColor;
  final Color backgroundColor;
  final Color borderColor;
  final String title;
  final List<Widget> tags;
  final List<Widget> details;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: leadingColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    leading,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTypography.displayFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: palette.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 4, children: tags),
                    ],
                    const SizedBox(height: 4),
                    ...details,
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: actions),
        ],
      ),
    );
  }
}

class _StopsTimelineSheet extends StatelessWidget {
  const _StopsTimelineSheet({
    required this.cubit,
    required this.onNavigateTo,
    required this.onSkip,
    required this.onFinish,
  });

  final ActiveTripCubit cubit;
  final ValueChanged<NavigationSessionItem> onNavigateTo;
  final ValueChanged<NavigationSessionItem> onSkip;
  final VoidCallback onFinish;

  static Future<void> show(
    BuildContext context, {
    required ActiveTripCubit cubit,
    required ValueChanged<NavigationSessionItem> onNavigateTo,
    required ValueChanged<NavigationSessionItem> onSkip,
    required VoidCallback onFinish,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StopsTimelineSheet(
        cubit: cubit,
        onNavigateTo: onNavigateTo,
        onSkip: onSkip,
        onFinish: onFinish,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    return BlocBuilder<ActiveTripCubit, ActiveTripState>(
      bloc: cubit,
      builder: (sheetContext, state) {
        final session = state.session;
        final exploring = state.exploringItem;
        final isBusy = state.isSubmitting || state.isTerminal;

        return Container(
          key: const Key('stops_timeline_sheet'),
          decoration: BoxDecoration(
            color: palette.canvas,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Lộ trình chuyến đi',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontFamily: AppTypography.displayFont,
                                      fontWeight: FontWeight.w700,
                                      color: palette.ink,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: palette.softAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${state.reachedWaypointsCount}/${state.totalWaypointsCount} đã đến',
                                maxLines: 1,
                                style: TextStyle(
                                  color: palette.primary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: palette.ink),
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: palette.border),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: state.items.length,
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return _TimelineStopRow(
                        item: item,
                        isFirst: index == 0,
                        isLast: index == state.items.length - 1,
                        isTarget: item.itemId == state.targetItemId,
                        isSuggested: item.itemId == session?.nextItemId,
                        isExploringHere: item.itemId == exploring?.itemId,
                        isBusy: isBusy,
                        onNavigateTo: () {
                          Navigator.of(sheetContext).pop();
                          onNavigateTo(item);
                        },
                        onSkip: () {
                          Navigator.of(sheetContext).pop();
                          onSkip(item);
                        },
                      );
                    },
                  ),
                ),
                Divider(height: 1, color: palette.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.ink,
                            side: BorderSide(color: palette.border),
                            backgroundColor: palette.surface,
                            minimumSize: const Size.fromHeight(46),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('Đóng', maxLines: 1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: OutlinedButton(
                          onPressed: isBusy
                              ? null
                              : () {
                                  Navigator.of(sheetContext).pop();
                                  onFinish();
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.error,
                            side: BorderSide(color: palette.error),
                            backgroundColor: palette.surface,
                            minimumSize: const Size.fromHeight(46),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text(
                            'Kết thúc chuyến',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
}

class _TimelineStopRow extends StatelessWidget {
  const _TimelineStopRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.isTarget,
    required this.isSuggested,
    required this.isExploringHere,
    required this.isBusy,
    required this.onNavigateTo,
    required this.onSkip,
  });

  final NavigationSessionItem item;
  final bool isFirst;
  final bool isLast;
  final bool isTarget;
  final bool isSuggested;
  final bool isExploringHere;
  final bool isBusy;
  final VoidCallback onNavigateTo;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    final isActive = isTarget || isExploringHere;
    final badgeColor = item.isReached
        ? palette.success
        : isActive
        ? palette.primary
        : item.status == NavigationItemStatus.skipped
        ? palette.warningText
        : palette.secondary;

    final statusText = switch (item.status) {
      NavigationItemStatus.reached =>
        'Đã đến lúc ${item.reachedAt == null ? '' : _formatTime(item.reachedAt!)}'
            .trim(),
      NavigationItemStatus.skipped => 'Đã bỏ qua',
      NavigationItemStatus.pending =>
        'Dự kiến ${_formatTime(item.plannedArrival)}',
    };

    final canNavigate = item.isReachable && !isTarget;
    final canSkip = item.status == NavigationItemStatus.pending;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 14,
                  color: isFirst
                      ? Colors.transparent
                      : palette.border.withValues(alpha: 0.9),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: item.isReached
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : Text(
                            '${item.displayNumber}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : palette.border.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? palette.softAccent
                      : item.isReached
                      ? palette.canvas
                      : palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? palette.primary : palette.border,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.poiName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: item.isReached ? palette.secondary : palette.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: item.status == NavigationItemStatus.skipped
                                ? palette.warningText
                                : palette.secondary,
                            fontWeight:
                                item.status == NavigationItemStatus.skipped
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (isExploringHere)
                          _CoastalPillTag(
                            label: 'Đang ở đây',
                            background: palette.success,
                            foreground: Colors.white,
                          )
                        else if (isTarget)
                          _CoastalPillTag(
                            label: 'Đang dẫn đường',
                            background: palette.primary,
                            foreground: Colors.white,
                          ),
                        if (isSuggested && !isExploringHere)
                          _CoastalPillTag(
                            label: 'Gợi ý tiếp theo',
                            background: palette.softAccent,
                            foreground: palette.primary,
                          ),
                        if (item.isMandatory)
                          _CoastalPillTag(
                            label: 'Bắt buộc',
                            background: palette.warningBg,
                            foreground: palette.warningText,
                          ),
                      ],
                    ),
                    if ((canNavigate || canSkip) && !isBusy) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (canNavigate)
                            OutlinedButton.icon(
                              key: Key('stop_navigate_${item.itemId}'),
                              onPressed: onNavigateTo,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: palette.primary,
                                side: BorderSide(color: palette.primary),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              icon: const Icon(Icons.near_me_rounded, size: 14),
                              label: const Text('Dẫn đường'),
                            ),
                          if (canSkip)
                            TextButton(
                              key: Key('stop_skip_${item.itemId}'),
                              onPressed: onSkip,
                              style: TextButton.styleFrom(
                                foregroundColor: palette.secondary,
                                backgroundColor: palette.canvas,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Bỏ qua'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
    final palette = CoastalPalette.of(context);
    return Material(
      elevation: 4,
      shadowColor: palette.ink.withValues(alpha: 0.2),
      shape: CircleBorder(side: BorderSide(color: palette.border)),
      color: palette.surface.withValues(alpha: 0.96),
      child: IconButton(
        icon: Icon(icon, color: palette.primary, size: 20),
        constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        padding: EdgeInsets.zero,
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
    final palette = CoastalPalette.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: palette.ink.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(fontSize: 11.5, color: palette.ink),
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
