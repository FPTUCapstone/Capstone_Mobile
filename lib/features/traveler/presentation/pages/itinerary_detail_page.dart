import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/external_review_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_suggestion_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/itinerary_stops.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_detail_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/itinerary_route_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/helpers/itinerary_map_data.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/external_reviews_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_cost_summary.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_leg_row.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_map.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_stop_card.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/itinerary_suggestions_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_map.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_page_scaffold.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';

final class ItineraryDetailPage extends StatefulWidget {
  const ItineraryDetailPage({
    required this.itineraryId,
    this.suggestionRepository,
    this.reviewRepository,
    this.directionsRepository,
    this.useMapbox,
    super.key,
  });

  final int itineraryId;

  /// Routes the map legs; defaults to the registered Mapbox Directions.
  final RouteDirectionsRepository? directionsRepository;

  /// Defaults to whether a Mapbox token is configured (else a drawn map).
  final bool? useMapbox;

  /// Default to the registered repositories; without them the add, replace
  /// and review actions are hidden.
  final ItinerarySuggestionRepository? suggestionRepository;
  final ExternalReviewRepository? reviewRepository;

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
  final _mapKey = GlobalKey<TripMapState>();
  final _rowKeys = <int, GlobalKey>{};
  int? _highlightedItemId;

  @override
  void initState() {
    super.initState();
    context.read<ItineraryDetailCubit>().load(widget.itineraryId);
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
              onRetry: () =>
                  context.read<ItineraryDetailCubit>().load(widget.itineraryId),
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
    this.suggestionRepository,
    this.reviewRepository,
    this.map,
    this.highlightedItemId,
  });

  final ItineraryDetailState state;
  final ItinerarySuggestionRepository? suggestionRepository;
  final ExternalReviewRepository? reviewRepository;
  final Widget? map;
  final int? highlightedItemId;
  final GlobalKey Function(int itemId) rowKeyOf;
  final ValueChanged<ItineraryDetailItem> onSelectItem;

  @override
  Widget build(BuildContext context) {
    final detail = state.detail!;
    final cubit = context.read<ItineraryDetailCubit>();
    final isDraft = detail.status == 'Draft';
    final visits = detail.visitItems;
    final usesMotorbike = detail.items.any(
      (item) =>
          item.travelDurationFromPreviousMinutes != null &&
          (item.transportModeFromPrevious ?? detail.transportMode) ==
              TransportMode.motorbike,
    );
    final canAddFood = state.canEditNow && suggestionRepository != null;
    final lunchSlot = ItineraryStops.lunchSlotAfterItemId(detail);
    return AppPageScaffold(
      title: detail.title ?? 'Lịch trình của bạn',
      actions: [
        if (detail.canEdit)
          IconButton(
            tooltip: 'Tạo lại lịch trình',
            onPressed: state.isBusy ? null : () => _regenerate(context),
            icon: const Icon(Icons.refresh),
          ),
      ],
      content: [
        Row(
          children: [
            Chip(label: Text('Phiên bản ${detail.version}')),
            const SizedBox(width: AppSpacing.xs),
            Chip(label: Text(_statusLabel(detail.status))),
            const Spacer(),
            Flexible(
              child: Text(
                detail.canManage
                    ? 'Chủ lịch trình'
                    : 'Chỉ xem (thành viên nhóm)',
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (map case final map?) ...[
          map,
          const SizedBox(height: AppSpacing.sm),
        ],
        ItineraryCostSummary(detail: detail),
        if (detail.items
                .where((item) => item.itemKind == ItineraryItemKind.visit)
                .length <=
            1) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Chỉ có ít địa điểm vừa lịch trình này. Nhiều điểm tham quan đóng cửa '
            'vào cuối chiều, nên bắt đầu sớm hơn, thêm thời gian hoặc mở rộng '
            'bán kính thường cho lịch trình đầy đủ hơn.',
            key: const Key('few_stops_hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (usesMotorbike) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Thời gian đi xe máy được ước tính theo đường ô tô.',
            key: const Key('motorbike_note'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
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
          return [
            if (spansDays && startsNewDay)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xs,
                ),
                child: Text(
                  tripDate(item.plannedArrival),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            if (travelMinutes != null && entry.key > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: ItineraryLegRow(
                  minutes: travelMinutes,
                  meters: item.travelDistanceFromPreviousMeters,
                  mode: item.transportModeFromPrevious ?? detail.transportMode,
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
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ItineraryStopCard(
                key: rowKeyOf(item.itemId),
                item: item,
                isHighlighted: item.itemId == highlightedItemId,
                onTap: visitIndex < 0 ? null : () => onSelectItem(item),
                stopNumber: visitIndex < 0 ? null : visitIndex + 1,
                shiftMinutes: item.poiId == null
                    ? null
                    : state.shiftedArrivals[item.poiId],
                actions: visitIndex < 0
                    ? const {}
                    : _actionsFor(item, visits.length),
                onAction: (action) => _onStopAction(context, item, action),
              ),
            ),
            if (item.itemId == lunchSlot && canAddFood)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Card(
                  key: const Key('lunch_card'),
                  child: ListTile(
                    title: const Text('🍜 Bữa trưa?'),
                    subtitle: const Text('Thêm một quán ăn gần chặng này.'),
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
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addFood(context, visits.last),
              icon: const Icon(Icons.add),
              label: const Text('Thêm quán ăn'),
            ),
          ),
        if (detail.status == 'Active') ...[
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: state.isBusy
                ? null
                : () => context.push(
                    AppRoutes.activeTripLive(detail.itineraryId),
                    extra: detail,
                  ),
            icon: const Icon(Icons.navigation_rounded),
            label: const Text('Bắt đầu dẫn đường'),
          ),
        ],
        if (detail.canManage && isDraft) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Chấp nhận lịch trình',
            onPressed: state.isBusy ? null : cubit.accept,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chấp nhận lịch trình để bắt đầu dẫn đường.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (detail.isNavigationInProgress) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Chuyến đi đang được dẫn đường trên ứng dụng. Hãy kết thúc chuyến '
            'đi trước khi thay đổi địa điểm.',
            key: const Key('navigation_in_progress_notice'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (detail.canEdit) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: state.isBusy ? null : () => _openEditor(context, detail),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Sắp xếp hoặc bỏ địa điểm'),
          ),
        ],
      ],
    );
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
        if (context.mounted) {
          await context.read<ItineraryDetailCubit>().removeStop(poiId);
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
    return showItinerarySuggestionsSheet(
      context,
      repository: repository,
      reviewRepository: reviewRepository,
      itineraryId: detail.itineraryId,
      kind: kind,
      itemId: item.itemId,
      stopName: (poiId) => names[poiId],
    );
  }

  static String _statusLabel(String status) => switch (status) {
    'Draft' => 'Bản nháp',
    'Active' => 'Đang dùng',
    _ => status,
  };

  Future<void> _regenerate(BuildContext context) async {
    final cubit = context.read<ItineraryDetailCubit>();
    final hasRestaurant = state.detail?.visitItems.any((item) => item.isFood);
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
    final ids = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditItemsSheet(items: detail.visitItems),
    );
    if (ids != null && context.mounted) {
      await context.read<ItineraryDetailCubit>().reorder(ids);
    }
  }
}

final class _EditItemsSheet extends StatefulWidget {
  const _EditItemsSheet({required this.items});

  final List<ItineraryDetailItem> items;

  @override
  State<_EditItemsSheet> createState() => _EditItemsSheetState();
}

final class _EditItemsSheetState extends State<_EditItemsSheet> {
  late final List<ItineraryDetailItem> _items = [...widget.items];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Điều chỉnh địa điểm',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                itemCount: _items.length,
                onReorderItem: (oldIndex, newIndex) => setState(() {
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                }),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    key: ValueKey(item.itemId),
                    title: Text(item.poiName ?? 'Điểm tham quan'),
                    subtitle: Text(
                      item.isMandatory ? 'Điểm bắt buộc' : 'Gợi ý',
                    ),
                    trailing: item.isMandatory
                        ? const Icon(Icons.lock_outline)
                        : IconButton(
                            tooltip: 'Bỏ ${item.poiName ?? 'địa điểm'}',
                            onPressed: () =>
                                setState(() => _items.removeAt(index)),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Lưu thay đổi',
              onPressed: _items.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      _items.map((item) => item.poiId!).toList(growable: false),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
