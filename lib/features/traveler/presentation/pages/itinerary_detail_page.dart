import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/router/create_travel_group_route_args.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/support_chat/domain/entities/support_chat.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/pending_explanation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/external_review_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_suggestion_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_weather_tips_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/itinerary_stops.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_route_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_weather_tips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_weather_tips_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_map_data.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_text.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/external_reviews_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_cost_summary.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_leg_row.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_map.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_stop_card.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_suggestions_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_weather_tips_card.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_map.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

final class ItineraryDetailPage extends StatefulWidget {
  const ItineraryDetailPage({
    required this.itineraryId,
    this.pendingExplanation,
    this.suggestionRepository,
    this.reviewRepository,
    this.weatherTipsRepository,
    this.directionsRepository,
    this.useMapbox,
    super.key,
  });

  final int itineraryId;

  /// UC-10: set when this itinerary was just created and its AI sentences are
  /// still being written; the page then refreshes them (see
  /// [ItineraryDetailCubit.load]).
  final PendingExplanation? pendingExplanation;

  /// Routes the map legs; defaults to the registered Mapbox Directions.
  final RouteDirectionsRepository? directionsRepository;

  /// Defaults to whether a Mapbox token is configured (else a drawn map).
  final bool? useMapbox;

  /// Default to the registered repositories; without them the add, replace
  /// and review actions are hidden.
  final ItinerarySuggestionRepository? suggestionRepository;
  final ExternalReviewRepository? reviewRepository;

  /// UC-10: where the weather tips come from; defaults to the registered one.
  /// Without a repository the weather card is never shown.
  final ItineraryWeatherTipsRepository? weatherTipsRepository;

  @override
  State<ItineraryDetailPage> createState() => _ItineraryDetailPageState();
}

final class _ItineraryDetailPageState extends State<ItineraryDetailPage> {
  late final _routeCubit = ItineraryRouteCubit(
    directions:
        widget.directionsRepository ??
        locateOptional<RouteDirectionsRepository>(),
  );
  late final bool _useMapbox =
      widget.useMapbox ??
      (locateOptional<AppConfig>()?.mapboxAccessToken != null);
  late final _weatherCubit = ItineraryWeatherTipsCubit(
    repository:
        widget.weatherTipsRepository ??
        locateOptional<ItineraryWeatherTipsRepository>(),
  );
  final _mapKey = GlobalKey<TripMapState>();
  final _rowKeys = <int, GlobalKey>{};
  int? _highlightedItemId;

  @override
  void initState() {
    super.initState();
    context.read<ItineraryDetailCubit>().load(
      widget.itineraryId,
      pendingExplanation: widget.pendingExplanation,
    );
  }

  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    // The undo snackbar must not outlive the page (its cubit closes with it).
    _messenger?.hideCurrentSnackBar();
    _routeCubit.close();
    _weatherCubit.close();
    super.dispose();
  }

  /// A map marker was tapped: highlight its stop and scroll the list to it.
  void _selectMarker(int markerId) {
    final key = _rowKeys[markerId];
    if (key == null) return;
    setState(() => _highlightedItemId = markerId);
    final rowContext = key.currentContext;
    if (rowContext != null) {
      Scrollable.ensureVisible(
        rowContext,
        duration: const Duration(milliseconds: 300),
        alignment: 0.3,
      );
    }
  }

  /// A stop was tapped: highlight it and move the map camera there.
  void _selectItem(ItineraryDetailItem item) {
    setState(() => _highlightedItemId = item.itemId);
    final latitude = item.latitude;
    final longitude = item.longitude;
    if (latitude != null && longitude != null) {
      _mapKey.currentState?.focus(
        NavigationCoordinate(latitude: latitude, longitude: longitude),
      );
    }
  }

  Widget? _buildMap(ItineraryDetail detail) {
    final data = ItineraryMapData.fromDetail(detail);
    if (data.markers.isEmpty) return null;
    return BlocBuilder<ItineraryRouteCubit, ItineraryRouteState>(
      bloc: _routeCubit,
      builder: (context, route) => ItineraryMap(
        data: data,
        lines: route.lines,
        useMapbox: _useMapbox,
        mapKey: _mapKey,
        highlightedMarkerId: _highlightedItemId,
        onMarkerTap: _selectMarker,
        height: 230,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ItineraryDetailCubit, ItineraryDetailState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.editRevision != current.editRevision ||
          previous.detail != current.detail,
      listener: (context, state) {
        final detail = state.detail;
        if (detail != null) {
          // Redraw the route for the new version (only changed legs are
          // routed again).
          _routeCubit.load(ItineraryMapData.fromDetail(detail).legs);
          // UC-10: weather tips, asked for once the itinerary has loaded
          // (the cubit ignores an id it already asked for).
          unawaited(_weatherCubit.load(detail.itineraryId));
        }
        final messenger = ScaffoldMessenger.of(context);
        if (state.status == ItineraryDetailStatus.failure &&
            state.message != null &&
            state.detail != null) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message!)));
          return;
        }
        if (state.status == ItineraryDetailStatus.loaded &&
            state.undoStops != null) {
          final cubit = context.read<ItineraryDetailCubit>();
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: const Text('Đã cập nhật lịch trình.'),
                duration: const Duration(seconds: 6),
                action: SnackBarAction(
                  label: 'Hoàn tác',
                  onPressed: cubit.undo,
                ),
              ),
            );
        }
      },
      builder: (context, state) {
        if (state.status == ItineraryDetailStatus.loading &&
            state.detail == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.detail == null) {
          return Scaffold(
            body: ErrorView(
              message: state.message ?? 'Lịch trình không khả dụng.',
              onRetry: () => context.read<ItineraryDetailCubit>().load(
                widget.itineraryId,
                pendingExplanation: widget.pendingExplanation,
              ),
            ),
          );
        }
        return _DetailContent(
          state: state,
          suggestionRepository:
              widget.suggestionRepository ??
              locateOptional<ItinerarySuggestionRepository>(),
          reviewRepository:
              widget.reviewRepository ??
              locateOptional<ExternalReviewRepository>(),
          map: _buildMap(state.detail!),
          weatherCubit: _weatherCubit,
          highlightedItemId: _highlightedItemId,
          rowKeyOf: (itemId) => _rowKeys.putIfAbsent(itemId, GlobalKey.new),
          onSelectItem: _selectItem,
        );
      },
    );
  }
}

final class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.state,
    required this.rowKeyOf,
    required this.onSelectItem,
    required this.weatherCubit,
    this.suggestionRepository,
    this.reviewRepository,
    this.map,
    this.highlightedItemId,
  });

  final ItineraryDetailState state;
  final ItinerarySuggestionRepository? suggestionRepository;
  final ExternalReviewRepository? reviewRepository;
  final Widget? map;
  final ItineraryWeatherTipsCubit weatherCubit;
  final int? highlightedItemId;
  final GlobalKey Function(int itemId) rowKeyOf;
  final ValueChanged<ItineraryDetailItem> onSelectItem;

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    final detail = state.detail!;
    final cubit = context.read<ItineraryDetailCubit>();
    final isDraft = detail.status == 'Draft';
    final visits = detail.visitItems;
    final displayTitle = formatTripDisplayTitle(
      title: detail.title,
      previewStopNames: visits
          .map((item) => item.poiName ?? '')
          .where((name) => name.isNotEmpty)
          .toList(growable: false),
      validFrom: detail.validFrom,
      fallback: 'Lịch trình của bạn',
    );
    final usesMotorbike = detail.items.any(
      (item) =>
          item.travelDurationFromPreviousMinutes != null &&
          (item.transportModeFromPrevious ?? detail.transportMode) ==
              TransportMode.motorbike,
    );
    final canAddFood = state.canEditNow && suggestionRepository != null;
    final lunchSlot = ItineraryStops.lunchSlotAfterItemId(detail);
    final hasStickyBar =
        detail.status == 'Active' ||
        (detail.canManage && isDraft) ||
        detail.canEdit ||
        detail.isNavigationInProgress;

    final subMeta = <String>[
      if (detail.validFrom case final from?) vietnameseShortDate(from),
      if (detail.transportMode case final mode?) transportLabel(mode),
    ];

    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        backgroundColor: palette.canvas,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: Navigator.canPop(context) ? 0 : AppSpacing.md,
        title: Text(
          'Chi tiết lịch trình',
          style: TextStyle(
            fontFamily: AppTypography.displayFont,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải để dùng offline',
            icon: const Icon(Icons.download_for_offline_outlined),
            onPressed: () => context.push(
              AppRoutes.offlinePackage(detail.itineraryId),
              extra: displayTitle,
            ),
          ),
          IconButton(
            tooltip: 'Ask about this itinerary',
            icon: const Icon(Icons.support_agent),
            onPressed: () => context.push(
              AppRoutes.supportChat,
              extra: SupportChatContext(
                kind: 'itinerary',
                id: detail.itineraryId.toString(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: !hasStickyBar,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                4,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: [
                // Coastal Heritage header card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _HeaderPill(
                                  label: _statusLabel(detail.status),
                                  bg: isDraft
                                      ? palette.warningBg
                                      : palette.softAccent,
                                  fg: isDraft
                                      ? palette.warningText
                                      : palette.primary,
                                ),
                                Text(
                                  '#${detail.itineraryId} · v${detail.version}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.secondary,
                                  ),
                                ),
                                if (_provenanceLabel(detail.provenance)
                                    case final provenance?)
                                  _HeaderPill(
                                    label: provenance,
                                    bg: palette.softAccent,
                                    fg: palette.primary,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            detail.canManage
                                ? 'Chủ lịch trình'
                                : 'Chỉ xem (thành viên nhóm)',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: palette.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFamily: AppTypography.displayFont,
                          fontSize: 19,
                          height: 1.24,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                      if (subMeta.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          subMeta.join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.secondary,
                          ),
                        ),
                      ],
                      if (detail.canEdit) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _HeaderActionPill(
                              palette: palette,
                              label: 'Chỉnh sửa thứ tự',
                              onTap: state.isBusy
                                  ? null
                                  : () => _openEditor(context, detail),
                            ),
                            Tooltip(
                              message: 'Tạo lại lịch trình',
                              child: _HeaderActionPill(
                                palette: palette,
                                label: 'Tạo lại lịch trình',
                                onTap: state.isBusy
                                    ? null
                                    : () => _regenerate(context),
                              ),
                            ),
                            _HeaderActionPill(
                              palette: palette,
                              label: 'Tùy chỉnh lại',
                              onTap: state.isBusy
                                  ? null
                                  : () => GoRouter.maybeOf(
                                      context,
                                    )?.push(AppRoutes.createItinerary),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // ADR-002 (G3), SRS MSG35: the CSP did not finish in time.
                if (detail.provenance?.isHeuristicFallback ?? false) ...[
                  Container(
                    key: const Key('schedule_fallback_notice'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.warningBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.warningBorder),
                    ),
                    child: Text(
                      'Lịch trình được tạo bằng chế độ heuristic nhanh do bài toán '
                      'quá phức tạp để thuật toán CSP hoàn tất kịp thời.',
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.warningText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                ItineraryCostSummary(detail: detail),
                BlocBuilder<
                  ItineraryWeatherTipsCubit,
                  ItineraryWeatherTipsState
                >(
                  bloc: weatherCubit,
                  builder: (context, weather) {
                    final tips = weather.tips;
                    if (tips == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ItineraryWeatherTipsCard(tips: tips),
                    );
                  },
                ),
                if (map case final map?) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'Bản đồ lộ trình',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: palette.ink,
                              ),
                            ),
                            const Spacer(),
                            _HeaderPill(
                              label: '${visits.length} điểm mốc',
                              bg: palette.softAccent,
                              fg: palette.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        map,
                      ],
                    ),
                  ),
                ],
                if (visits.length <= 1) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Chỉ có ít địa điểm vừa lịch trình này. Nhiều điểm tham quan đóng cửa '
                    'vào cuối chiều, nên bắt đầu sớm hơn, thêm thời gian hoặc mở rộng '
                    'bán kính thường cho lịch trình đầy đủ hơn.',
                    key: const Key('few_stops_hint'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.secondary),
                  ),
                ],
                if (detail.bookedServices.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Dịch vụ đã đặt',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final service in detail.bookedServices)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(service.serviceName),
                      subtitle: Text(
                        'SR-${service.id} · Số lượng ${service.quantity} · ${service.status == 'Completed' ? 'Đã hoàn tất' : 'Đã xác nhận'}',
                      ),
                      trailing: Text(
                        TripFormatters.formatVietnamDateTime(service.startsAt),
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Lộ trình tham quan chi tiết (${detail.items.length} điểm dừng)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Divider(color: palette.border, height: 1),
                if (usesMotorbike) ...[
                  const SizedBox(height: 8),
                  Row(
                    key: const Key('motorbike_note'),
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: palette.secondary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'Thời gian đi xe máy được ước tính theo đường ô tô.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: palette.secondary),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                ...detail.items.asMap().entries.expand((entry) {
                  final item = entry.value;
                  final travelMinutes = item.travelDurationFromPreviousMinutes;
                  // Compared with the trip start too: an evening start whose stops all
                  // fall on the next morning still needs that morning's date.
                  final tripStart =
                      detail.validFrom ?? detail.items.first.plannedArrival;
                  final spansDays = !sameTripDay(
                    tripStart,
                    detail.items.last.plannedDeparture,
                  );
                  final startsNewDay =
                      entry.key == 0 ||
                      !sameTripDay(
                        detail.items[entry.key - 1].plannedArrival,
                        item.plannedArrival,
                      );
                  final previousItem = entry.key > 0
                      ? detail.items[entry.key - 1]
                      : null;
                  final isBetweenVisits =
                      previousItem != null &&
                      previousItem.itemKind == ItineraryItemKind.visit &&
                      item.itemKind == ItineraryItemKind.visit;
                  final visitIndex = visits.indexOf(item);
                  final canChangeLeg =
                      state.canEditNow && isBetweenVisits && visitIndex > 0;
                  final hasNext = entry.key < detail.items.length - 1;
                  return [
                    if (spansDays && startsNewDay)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.sm,
                          bottom: AppSpacing.xs,
                        ),
                        child: Text(
                          tripDate(item.plannedArrival),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: palette.primary),
                        ),
                      ),
                    if (travelMinutes != null && entry.key > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ItineraryLegRow(
                          minutes: travelMinutes,
                          meters: item.travelDistanceFromPreviousMeters,
                          mode:
                              item.transportModeFromPrevious ??
                              detail.transportMode,
                          destinationName: item.poiName,
                          showWalkHint: isBetweenVisits,
                          onChangeMode: canChangeLeg
                              ? (mode) => cubit.changeLegMode(
                                  toPoiId: item.poiId!,
                                  mode: mode,
                                )
                              : null,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ItineraryStopCard(
                        key: rowKeyOf(item.itemId),
                        item: item,
                        isHighlighted: item.itemId == highlightedItemId,
                        showTimelineConnector: hasNext,
                        onTap: visitIndex < 0 ? null : () => onSelectItem(item),
                        onOpenDetail: visitIndex < 0 || item.poiId == null
                            ? null
                            : () => GoRouter.maybeOf(context)?.push(
                                AppRoutes.poiDetail(
                                  item.poiId!,
                                  itineraryId: detail.canManage
                                      ? detail.itineraryId
                                      : null,
                                ),
                              ),
                        provenanceTag: _provenanceLabel(detail.provenance),
                        stopNumber: visitIndex < 0 ? null : visitIndex + 1,
                        shiftMinutes: item.poiId == null
                            ? null
                            : state.shiftedArrivals[item.poiId],
                        actions: visitIndex < 0
                            ? const {}
                            : _actionsFor(item, visits.length),
                        onAction: (action) =>
                            _onStopAction(context, item, action),
                      ),
                    ),
                    if (item.itemId == lunchSlot && canAddFood)
                      Padding(
                        padding: const EdgeInsets.only(left: 36, bottom: 8),
                        child: Container(
                          key: const Key('lunch_card'),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: palette.border),
                          ),
                          child: ListTile(
                            title: const Text('🍜 Bữa trưa?'),
                            subtitle: const Text(
                              'Thêm một quán ăn gần chặng này.',
                            ),
                            trailing: TextButton(
                              onPressed: () => _addFood(context, item),
                              child: const Text('Chọn quán'),
                            ),
                          ),
                        ),
                      ),
                  ];
                }),
                if (canAddFood && visits.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 36),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.primary,
                          side: BorderSide(color: palette.border),
                        ),
                        onPressed: () => _addFood(context, visits.last),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Thêm quán ăn'),
                      ),
                    ),
                  ),
                if (detail.canManage) ...[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('create_travel_group_button'),
                    onPressed: state.isBusy
                        ? null
                        : () {
                            final destination = detail.items.isNotEmpty
                                ? detail.items
                                      .firstWhere(
                                        (item) =>
                                            item.poiName != null &&
                                            item.poiName!.isNotEmpty,
                                        orElse: () => detail.items.first,
                                      )
                                      .poiName
                                : null;
                            final dateRange = tripSchedule(
                              detail.validFrom,
                              detail.validTo,
                            );
                            context.push(
                              AppRoutes.createTravelGroup,
                              extra: CreateTravelGroupRouteArgs(
                                itineraryId: detail.itineraryId,
                                itineraryTitle:
                                    detail.title ??
                                    'Lịch trình #${detail.itineraryId}',
                                destination: destination,
                                dateRange: dateRange,
                              ),
                            );
                          },
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Tạo nhóm du lịch'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: hasStickyBar
          ? _StickyDetailBar(
              palette: palette,
              detail: detail,
              isDraft: isDraft,
              isBusy: state.isBusy,
              onAccept: cubit.accept,
              onStartNavigation: () => context.push(
                AppRoutes.activeTripLive(detail.itineraryId),
                extra: detail,
              ),
              onOpenEditor: () => _openEditor(context, detail),
            )
          : null,
    );
  }

  static String? _provenanceLabel(ScheduleProvenance? provenance) {
    if (provenance == null) return null;
    if (provenance.solverOutcome == 'manual_order') return 'Thứ tự bạn chỉnh';
    if (provenance.isHeuristicFallback) return 'Chế độ nhanh';
    return 'Tối ưu lịch trình';
  }

  Set<ItineraryStopAction> _actionsFor(ItineraryDetailItem item, int visits) =>
      {
        if (state.canEditNow && suggestionRepository != null)
          ItineraryStopAction.replace,
        if (state.canEditNow && visits > 1) ItineraryStopAction.remove,
        if (reviewRepository != null && item.poiId != null)
          ItineraryStopAction.reviews,
      };

  Future<void> _onStopAction(
    BuildContext context,
    ItineraryDetailItem item,
    ItineraryStopAction action,
  ) async {
    final poiId = item.poiId;
    if (poiId == null) return;
    switch (action) {
      case ItineraryStopAction.replace:
        if (item.isMandatory &&
            !await _confirmMandatoryChange(context, item, replacing: true)) {
          return;
        }
        if (!context.mounted) return;
        final chosen = await _pickSuggestion(
          context,
          SuggestionKind.replace,
          item,
        );
        if (chosen != null && context.mounted) {
          await context.read<ItineraryDetailCubit>().replaceStop(
            oldPoiId: poiId,
            newPoiId: chosen.poiId,
            poiName: chosen.name,
          );
        }
      case ItineraryStopAction.remove:
        if (item.isMandatory &&
            !await _confirmMandatoryChange(context, item, replacing: false)) {
          return;
        }
        if (!context.mounted) return;
        final reason = await _askRemovalReason(context);
        if (reason != null && context.mounted) {
          await context.read<ItineraryDetailCubit>().removeStop(poiId, reason);
        }
      case ItineraryStopAction.reviews:
        final reviews = reviewRepository;
        if (reviews == null) return;
        await showExternalReviewsSheet(
          context,
          repository: reviews,
          poiId: poiId,
          poiName: item.poiName ?? 'Địa điểm',
        );
    }
  }

  /// Removing or replacing a must-see stop is allowed, after a confirmation
  /// (spec D4).
  Future<bool> _confirmMandatoryChange(
    BuildContext context,
    ItineraryDetailItem item, {
    required bool replacing,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(replacing ? 'Thay điểm bắt buộc?' : 'Bỏ điểm bắt buộc?'),
          content: Text(
            '${item.poiName ?? 'Địa điểm này'} là điểm bạn đã chọn phải đến. '
            '${replacing ? 'Thay' : 'Bỏ'} nó thì lần tạo lại sau cũng sẽ không '
            'thêm lại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Giữ lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(replacing ? 'Thay địa điểm' : 'Bỏ khỏi lịch'),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _addFood(BuildContext context, ItineraryDetailItem after) async {
    final afterPoiId = after.poiId;
    if (afterPoiId == null) return;
    final chosen = await _pickSuggestion(context, SuggestionKind.food, after);
    if (chosen != null && context.mounted) {
      await context.read<ItineraryDetailCubit>().insertStop(
        afterPoiId: afterPoiId,
        poiId: chosen.poiId,
        poiName: chosen.name,
      );
    }
  }

  Future<ItinerarySuggestion?> _pickSuggestion(
    BuildContext context,
    SuggestionKind kind,
    ItineraryDetailItem item,
  ) async {
    final repository = suggestionRepository;
    final detail = state.detail;
    if (repository == null || detail == null) return null;
    final names = {
      for (final visit in detail.visitItems) visit.poiId: visit.poiName,
    };
    final currentEndTime =
        detail.validTo ??
        (detail.items.isNotEmpty ? detail.items.last.plannedDeparture : null);
    return showItinerarySuggestionsSheet(
      context,
      repository: repository,
      reviewRepository: reviewRepository,
      itineraryId: detail.itineraryId,
      kind: kind,
      itemId: item.itemId,
      stopName: (poiId) => names[poiId],
      currentEndTime: currentEndTime,
      anchorName: item.poiName,
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'Draft' => 'Bản nháp',
    'Active' => 'Đang dùng',
    _ => status,
  };

  Future<void> _regenerate(BuildContext context) async {
    final cubit = context.read<ItineraryDetailCubit>();
    final hasRestaurant = state.detail?.visitItems.any(
      (item) => item.isFood && !item.isMandatory,
    );
    if (hasRestaurant == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Tạo lại lịch trình?'),
          content: const Text(
            'Lịch trình mới được tạo lại từ yêu cầu ban đầu, nên các quán ăn '
            'bạn đã thêm sẽ không được giữ lại.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Giữ lịch hiện tại'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Tạo lại'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await cubit.regenerate();
  }

  Future<void> _openEditor(BuildContext context, ItineraryDetail detail) async {
    final edit = await showModalBottomSheet<_ItemsEdit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditItemsSheet(items: detail.visitItems),
    );
    if (edit != null && context.mounted) {
      await context.read<ItineraryDetailCubit>().reorder(
        edit.orderedPoiIds,
        removalReasons: edit.removalReasons,
      );
    }
  }
}

final class _HeaderActionPill extends StatelessWidget {
  const _HeaderActionPill({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final CoastalPalette palette;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.surface,
      shape: StadiumBorder(side: BorderSide(color: palette.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: onTap == null ? palette.secondary : palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}

final class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

final class _StickyDetailBar extends StatelessWidget {
  const _StickyDetailBar({
    required this.palette,
    required this.detail,
    required this.isDraft,
    required this.isBusy,
    required this.onAccept,
    required this.onStartNavigation,
    required this.onOpenEditor,
  });

  final CoastalPalette palette;
  final ItineraryDetail detail;
  final bool isDraft;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onStartNavigation;
  final VoidCallback onOpenEditor;

  @override
  Widget build(BuildContext context) {
    final showAccept = detail.canManage && isDraft;
    final showNavigate = detail.status == 'Active';
    final showEdit = detail.canEdit;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (detail.isNavigationInProgress) ...[
                Text(
                  'Chuyến đi đang được dẫn đường trên ứng dụng. Hãy kết thúc chuyến '
                  'đi trước khi thay đổi địa điểm.',
                  key: const Key('navigation_in_progress_notice'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: palette.secondary),
                ),
                if (showNavigate) const SizedBox(height: 8),
              ],
              if (showAccept || showNavigate || showEdit)
                Row(
                  children: [
                    if (showEdit) ...[
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          key: const Key('reorder_stops_button'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.ink,
                            side: BorderSide(color: palette.border),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          onPressed: isBusy ? null : onOpenEditor,
                          icon: const Icon(Icons.swap_vert, size: 18),
                          label: const Text('Sắp xếp'),
                        ),
                      ),
                      if (showAccept || showNavigate) const SizedBox(width: 10),
                    ],
                    if (showNavigate)
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.primary,
                              foregroundColor: palette.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            onPressed: isBusy ? null : onStartNavigation,
                            icon: const Icon(
                              Icons.navigation_rounded,
                              size: 18,
                            ),
                            label: const Text('Bắt đầu dẫn đường'),
                          ),
                        ),
                      ),
                    if (showAccept)
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.primary,
                              foregroundColor: palette.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            onPressed: isBusy ? null : onAccept,
                            child: const Text('Chấp nhận lịch trình'),
                          ),
                        ),
                      ),
                  ],
                ),
              if (showAccept) ...[
                const SizedBox(height: 6),
                Text(
                  'Chấp nhận lịch trình để bắt đầu dẫn đường.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: palette.secondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What the editor sheet returns on "Lưu thay đổi": the kept stops in order
/// and why each dropped stop was dropped.
typedef _ItemsEdit = ({
  List<int> orderedPoiIds,
  Map<int, StopRemovalReason> removalReasons,
});

/// Asks why a stop is being removed. Picking a reason is the confirmation:
/// closing the sheet returns null and the stop stays.
Future<StopRemovalReason?> _askRemovalReason(BuildContext context) =>
    showModalBottomSheet<StopRemovalReason>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                'Vì sao bạn bỏ điểm này?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final (reason, label) in const [
              (StopRemovalReason.notInterested, 'Không thích'),
              (StopRemovalReason.noTime, 'Không đủ thời gian'),
              (StopRemovalReason.alreadyVisited, 'Đã đi rồi'),
            ])
              ListTile(
                title: Text(label),
                onTap: () => Navigator.of(context).pop(reason),
              ),
          ],
        ),
      ),
    );

final class _EditItemsSheet extends StatefulWidget {
  const _EditItemsSheet({required this.items});

  final List<ItineraryDetailItem> items;

  @override
  State<_EditItemsSheet> createState() => _EditItemsSheetState();
}

final class _EditItemsSheetState extends State<_EditItemsSheet> {
  late final List<ItineraryDetailItem> _items = [...widget.items];
  final _removalReasons = <int, StopRemovalReason>{};

  void _moveBy(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
    });
  }

  void _resetChanges() {
    setState(() {
      _items
        ..clear()
        ..addAll(widget.items);
      _removalReasons.clear();
    });
  }

  bool get _hasChanges {
    if (_items.length != widget.items.length) return true;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].itemId != widget.items[i].itemId) return true;
    }
    return false;
  }

  Future<void> _remove(ItineraryDetailItem item) async {
    final reason = await _askRemovalReason(context);
    if (reason == null || !mounted) return;
    setState(() {
      _items.remove(item);
      _removalReasons[item.poiId!] = reason;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoastalPalette.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Điều chỉnh địa điểm',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: AppTypography.displayFont,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Kéo biểu tượng ☰ hoặc bấm ↑ ↓ để đổi thứ tự. Điểm nghỉ được hệ thống giữ nguyên.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: palette.secondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                itemCount: _items.length,
                onReorderItem: (oldIndex, newIndex) => setState(() {
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                }),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final name = item.poiName ?? 'Điểm tham quan';
                  final badgeColor = item.isFood
                      ? const Color(0xFFD97706)
                      : palette.primary;
                  return Container(
                    key: ValueKey(item.itemId),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              size: 20,
                              color: palette.secondary,
                            ),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: palette.ink,
                                ),
                              ),
                              Text(
                                item.isMandatory ? 'Điểm bắt buộc' : 'Gợi ý',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: item.isMandatory
                                      ? palette.primary
                                      : palette.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đưa $name lên trên',
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 34,
                            height: 34,
                          ),
                          onPressed: index > 0
                              ? () => _moveBy(index, -1)
                              : null,
                          icon: const Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đưa $name xuống dưới',
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 34,
                            height: 34,
                          ),
                          onPressed: index < _items.length - 1
                              ? () => _moveBy(index, 1)
                              : null,
                          icon: const Icon(
                            Icons.arrow_downward_rounded,
                            size: 18,
                          ),
                        ),
                        if (item.isMandatory)
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: Center(
                              child: Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: palette.secondary,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            tooltip: 'Bỏ ${item.poiName ?? 'địa điểm'}',
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 34,
                              height: 34,
                            ),
                            onPressed: () => _remove(item),
                            icon: Icon(
                              Icons.remove_circle_outline,
                              size: 19,
                              color: palette.error,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (_hasChanges) ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.ink,
                      side: BorderSide(color: palette.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: _resetChanges,
                    child: const Text('Đặt lại'),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: palette.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: _items.isEmpty
                        ? null
                        : () => Navigator.of(context).pop((
                            orderedPoiIds: _items
                                .map((item) => item.poiId!)
                                .toList(),
                            removalReasons:
                                Map<int, StopRemovalReason>.unmodifiable(
                                  _removalReasons,
                                ),
                          )),
                    child: const Text('Lưu thay đổi'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
