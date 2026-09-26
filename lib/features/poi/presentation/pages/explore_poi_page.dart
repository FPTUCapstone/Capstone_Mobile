import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/poi/data/fixtures/category_fixtures.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_cubit.dart';
import 'package:trip_mate_mobile/features/poi/presentation/cubit/poi_list_state.dart';
import 'package:trip_mate_mobile/features/poi/presentation/theme/poi_palette.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_list_card.dart';
import 'package:trip_mate_mobile/features/poi/presentation/widgets/poi_map_preview.dart';

class ExplorePoiPage extends StatefulWidget {
  const ExplorePoiPage({
    this.isTraveler = false,
    this.showCategoryPreview,
    super.key,
  });

  final bool isTraveler;
  final bool? showCategoryPreview;

  @override
  State<ExplorePoiPage> createState() => _ExplorePoiPageState();
}

class _ExplorePoiPageState extends State<ExplorePoiPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<PoiListCubit>().state.query.search,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PoiPalette.background,
      body: SafeArea(
        child: BlocBuilder<PoiListCubit, PoiListState>(
          builder: (context, state) {
            final cubit = context.read<PoiListCubit>();
            return Column(
              children: [
                _ExploreHeader(
                  controller: _searchController,
                  isTraveler: widget.isTraveler,
                  onSearch: cubit.submitSearch,
                ),
                _ExploreControls(
                  state: state,
                  cubit: cubit,
                  showCategoryPreview:
                      widget.showCategoryPreview ?? _categoryPreviewEnabled(),
                ),
                if (state.locationMessage case final message?)
                  _InlineNotice(
                    message: message,
                    icon: Icons.location_off_outlined,
                    onDismiss: cubit.dismissLocationMessage,
                  ),
                if (state.validationFailure case final failure?)
                  _InlineNotice(
                    message:
                        failure.fieldErrors.values
                            .expand((messages) => messages)
                            .firstOrNull ??
                        failure.message,
                    icon: Icons.info_outline,
                  ),
                if (state.failure != null && state.items.isNotEmpty)
                  _InlineNotice(
                    message: state.failure!.message,
                    icon: Icons.cloud_off_outlined,
                  ),
                Expanded(
                  child: state.isMapView
                      ? PoiMapPreview(state: state, cubit: cubit)
                      : _PoiListBody(
                          state: state,
                          cubit: cubit,
                          onReset: () {
                            _searchController.clear();
                            cubit.resetFilters();
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _categoryPreviewEnabled() {
    if (!serviceLocator.isRegistered<AppConfig>()) return false;
    return serviceLocator<AppConfig>().categoryPreviewEnabled;
  }
}

class _ExploreHeader extends StatelessWidget {
  const _ExploreHeader({
    required this.controller,
    required this.isTraveler,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool isTraveler;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PoiPalette.teal,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TripMate',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        'Khám phá miền Trung',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isTraveler) ...[
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    foregroundColor: PoiPalette.teal,
                    child: Text(
                      'TM',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Xin chào, Du khách',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: () => context.go(AppRoutes.login),
                    icon: const Icon(Icons.login),
                    label: const Text('Đăng nhập'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: PoiPalette.tealDark,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLength: 200,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              textInputAction: TextInputAction.search,
              onSubmitted: onSearch,
              decoration: InputDecoration(
                hintText: 'Tìm danh lam, bãi biển, hang động…',
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  tooltip: 'Tìm kiếm',
                  onPressed: () => onSearch(controller.text),
                  icon: const Icon(Icons.arrow_forward),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreControls extends StatelessWidget {
  const _ExploreControls({
    required this.state,
    required this.cubit,
    required this.showCategoryPreview,
  });

  final PoiListState state;
  final PoiListCubit cubit;
  final bool showCategoryPreview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Danh sách'),
                      ),
                    ),
                    ButtonSegment(
                      value: true,
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Bản đồ'),
                      ),
                    ),
                  ],
                  selected: {state.isMapView},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    cubit.setMapView(selection.first);
                  },
                  style: ButtonStyle(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 6),
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? PoiPalette.teal
                          : Colors.white,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Colors.white
                          : PoiPalette.navy,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.tour_outlined, size: 18),
                  label: const Text('Tìm tour'),
                  onPressed: () => context.push(AppRoutes.tourSearch),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Đang mở cửa'),
                  avatar: const Icon(Icons.storefront_outlined, size: 18),
                  selected: state.query.openNow,
                  onSelected: cubit.setOpenNow,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
                const SizedBox(width: 8),
                PopupMenuButton<PoiSort>(
                  onSelected: cubit.setSort,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: PoiSort.name,
                      child: Text('Tên A–Z'),
                    ),
                    if (state.query.hasOrigin)
                      const PopupMenuItem(
                        value: PoiSort.distance,
                        child: Text('Gần nhất'),
                      ),
                    const PopupMenuItem(
                      value: PoiSort.rating,
                      child: Text('Đánh giá cao'),
                    ),
                  ],
                  child: _ControlChip(
                    icon: Icons.sort,
                    label: switch (state.query.sort) {
                      PoiSort.name => 'Tên A–Z',
                      PoiSort.distance => 'Gần nhất',
                      PoiSort.rating => 'Đánh giá cao',
                    },
                  ),
                ),
                if (state.query.hasOrigin) ...[
                  const SizedBox(width: 8),
                  const _ControlChip(
                    icon: Icons.near_me_outlined,
                    label: 'Có khoảng cách',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CategoryChip(
                  label: 'Tất cả',
                  selected: state.query.categoryId == null,
                  onSelected: () => cubit.selectCategory(null),
                ),
                if (showCategoryPreview)
                  for (final category in poiCategoryPreviewFixtures) ...[
                    const SizedBox(width: 8),
                    _CategoryChip(
                      label: category.name,
                      selected: state.query.categoryId == category.id,
                      onSelected: () => cubit.selectCategory(category.id),
                    ),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PoiListBody extends StatelessWidget {
  const _PoiListBody({
    required this.state,
    required this.cubit,
    required this.onReset,
  });

  final PoiListState state;
  final PoiListCubit cubit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (state.status == PoiListStatus.loading) {
      return const _PoiSkeletonList();
    }
    if (state.status == PoiListStatus.failure && state.items.isEmpty) {
      return _CenteredState(
        icon: Icons.cloud_off_outlined,
        title: 'Chưa thể tải địa điểm',
        message: state.failure?.message ?? 'Vui lòng thử lại.',
        actionLabel: 'Thử lại',
        onAction: cubit.loadInitial,
      );
    }
    if (state.items.isEmpty) {
      return _CenteredState(
        icon: Icons.travel_explore,
        title: 'Không tìm thấy địa điểm phù hợp',
        message: 'Hãy thử từ khóa hoặc bộ lọc khác.',
        actionLabel: 'Đặt lại tìm kiếm và bộ lọc',
        onAction: onReset,
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.maxScrollExtent > 0 &&
            notification.metrics.pixels >=
                notification.metrics.maxScrollExtent * 0.85) {
          cubit.loadNextPage();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: cubit.refresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: state.items.length + 2,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                'Tìm thấy ${state.totalCount} địa điểm',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: PoiPalette.navy,
                  fontWeight: FontWeight.w700,
                ),
              );
            }
            if (index > state.items.length) {
              return state.isLoadingMore
                  ? const _LoadingMore()
                  : const SizedBox.shrink();
            }
            final poi = state.items[index - 1];
            return PoiListCard(
              poi: poi,
              onTap: () => context.push(AppRoutes.poiDetail(poi.id)),
            );
          },
        ),
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  const _ControlChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: PoiPalette.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      selectedColor: PoiPalette.teal,
      labelStyle: TextStyle(
        color: selected ? Colors.white : PoiPalette.navy,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    required this.icon,
    this.onDismiss,
  });

  final String message;
  final IconData icon;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: PoiPalette.tealSoft,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          leading: Icon(icon, color: PoiPalette.teal),
          title: Text(message),
          trailing: onDismiss == null
              ? null
              : IconButton(
                  onPressed: onDismiss,
                  tooltip: 'Đóng thông báo',
                  icon: const Icon(Icons.close),
                ),
        ),
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: PoiPalette.teal),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _PoiSkeletonList extends StatelessWidget {
  const _PoiSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 126,
        decoration: BoxDecoration(
          color: Colors.white54,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 84,
              decoration: BoxDecoration(
                color: PoiPalette.line,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 18, color: PoiPalette.line),
                  const SizedBox(height: 10),
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: Container(height: 14, color: PoiPalette.line),
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

class _LoadingMore extends StatelessWidget {
  const _LoadingMore();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Đang tải thêm địa điểm',
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
