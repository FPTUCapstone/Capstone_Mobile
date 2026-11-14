import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/storage/preferences_service.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_cubit.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/cubit/tour_search_state.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/resources/public_search_copy.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/theme/tour_search_palette.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/widgets/dev_tour_search_controls.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/widgets/public_tour_search_controls.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/widgets/tour_list_card.dart';

class TourSearchPage extends StatefulWidget {
  const TourSearchPage({this.isTraveler = false, super.key});

  final bool isTraveler;

  @override
  State<TourSearchPage> createState() => _TourSearchPageState();
}

class _TourSearchPageState extends State<TourSearchPage> {
  static const _localeKey = 'tripmate.uc24.locale';
  PreferencesService? get _preferences =>
      serviceLocator.isRegistered<PreferencesService>()
      ? serviceLocator<PreferencesService>()
      : null;
  String? _selection;

  @override
  void initState() {
    super.initState();
    _selection = _preferences?.getString(_localeKey);
  }

  @override
  Widget build(BuildContext context) {
    final locale =
        publicSearchUsesEnglish(
          _selection,
          View.of(context).platformDispatcher.locale.languageCode,
        )
        ? 'en'
        : 'vi';
    return Scaffold(
      backgroundColor: TourSearchPalette.background,
      body: SafeArea(
        child: BlocBuilder<TourSearchCubit, TourSearchState>(
          builder: (context, state) {
            final cubit = context.read<TourSearchCubit>();
            final useEnglish = cubit.devSearchEnabled || locale == 'en';
            return Column(
              children: [
                _TourSearchHeader(
                  isTraveler: widget.isTraveler,
                  useEnglish: useEnglish,
                  onFilterTap: () => _openFilterSheet(context, cubit, locale),
                ),
                if (!cubit.devSearchEnabled)
                  DropdownButton<String>(
                    value: locale,
                    hint: Text(
                      publicSearchCopy(SearchText.language, useEnglish),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() => _selection = value);
                      await _preferences?.setString(_localeKey, value);
                    },
                  ),
                _ActiveFilters(
                  state: state,
                  cubit: cubit,
                  useEnglish: useEnglish,
                ),
                if (cubit.devSearchEnabled)
                  DevTourSearchControls(state: state, cubit: cubit),
                if (!cubit.devSearchEnabled)
                  PublicTourSearchControls(
                    state: state,
                    cubit: cubit,
                    useEnglish: useEnglish,
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
                    message: cubit.devSearchEnabled
                        ? state.failure!.message
                        : publicSearchCopy(SearchText.systemError, useEnglish),
                    icon: Icons.cloud_off_outlined,
                    actionLabel: cubit.devSearchEnabled
                        ? 'Retry search'
                        : publicSearchCopy(SearchText.retry, useEnglish),
                    onAction: cubit.retryFailedQuery,
                  ),
                Expanded(
                  child: _TourListBody(
                    state: state,
                    cubit: cubit,
                    useEnglish: useEnglish,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openFilterSheet(
    BuildContext context,
    TourSearchCubit cubit,
    String locale,
  ) {
    if (cubit.devSearchEnabled) {
      cubit.loadCategories();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DevTourSearchFilterSheet(cubit: cubit),
      );
      return;
    }
    cubit.loadCategories();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          PublicTourSearchFilterSheet(cubit: cubit, useEnglish: locale == 'en'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _TourSearchHeader extends StatelessWidget {
  const _TourSearchHeader({
    required this.isTraveler,
    required this.onFilterTap,
    required this.useEnglish,
  });

  final bool isTraveler;
  final VoidCallback onFilterTap;
  final bool useEnglish;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TourSearchPalette.teal,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Brand
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: TourSearchPalette.navy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.route, color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TripMate',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        publicSearchCopy(SearchText.title, useEnglish),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                // Tours badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'TOURS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: TourSearchPalette.teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!isTraveler) ...[
                  const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    height: 40,
                    child: FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.login),
                      icon: const Icon(Icons.login, size: 18),
                      label: Text(
                        publicSearchCopy(SearchText.signIn, useEnglish),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        backgroundColor: TourSearchPalette.tealDark,
                        foregroundColor: Colors.white,
                        textStyle: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Filter button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onFilterTap,
                icon: const Icon(Icons.tune, size: 20),
                label: Text(
                  publicSearchCopy(SearchText.filterAction, useEnglish),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: TourSearchPalette.navy,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Filters
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.state,
    required this.cubit,
    required this.useEnglish,
  });

  final TourSearchState state;
  final TourSearchCubit cubit;
  final bool useEnglish;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (state.query.destination != null &&
        state.query.destination!.trim().isNotEmpty) {
      chips.add(
        _FilterChip(
          label: state.query.destination!,
          icon: Icons.place_outlined,
        ),
      );
    }
    if (state.query.departureDate != null) {
      final d = state.query.departureDate!;
      chips.add(
        _FilterChip(
          label:
              '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
          icon: Icons.calendar_today_outlined,
        ),
      );
    }
    if (state.query.minPrice != null) {
      chips.add(
        _FilterChip(
          label: publicSearchPriceBound(
            _formatVndShort(state.query.minPrice!),
            useEnglish,
            minimum: true,
          ),
          icon: Icons.arrow_upward,
        ),
      );
    }
    if (state.query.maxPrice != null) {
      chips.add(
        _FilterChip(
          label: publicSearchPriceBound(
            _formatVndShort(state.query.maxPrice!),
            useEnglish,
            minimum: false,
          ),
          icon: Icons.arrow_downward,
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.xs),
                    chips[i],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            height: 32,
            child: TextButton(
              onPressed: cubit.resetFilters,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                minimumSize: Size.zero,
              ),
              child: Text(
                publicSearchCopy(SearchText.clearChip, useEnglish),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: TourSearchPalette.soldOut,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatVndShort(int price) {
    if (price >= 1000000) {
      final m = price / 1000000;
      return m == m.truncateToDouble()
          ? '${m.toInt()}tr'
          : '${m.toStringAsFixed(1)}tr';
    }
    if (price >= 1000) {
      return '${price ~/ 1000}k';
    }
    return '$price₫';
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: TourSearchPalette.tealSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: TourSearchPalette.teal.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: TourSearchPalette.teal),
          const SizedBox(width: AppSpacing.xxs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: TourSearchPalette.tealDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List Body
// ─────────────────────────────────────────────────────────────────────────────

class _TourListBody extends StatelessWidget {
  const _TourListBody({
    required this.state,
    required this.cubit,
    required this.useEnglish,
  });

  final TourSearchState state;
  final TourSearchCubit cubit;
  final bool useEnglish;

  @override
  Widget build(BuildContext context) {
    if (state.status == TourSearchStatus.loading) {
      return const _TourSkeletonList();
    }
    if (state.status == TourSearchStatus.failure && state.items.isEmpty) {
      return _CenteredState(
        icon: Icons.cloud_off_outlined,
        title: publicSearchCopy(SearchText.loadFailed, useEnglish),
        message:
            (cubit.devSearchEnabled
                ? state.failure?.message
                : publicSearchCopy(SearchText.systemError, useEnglish)) ??
            publicSearchCopy(SearchText.systemError, useEnglish),
        actionLabel: publicSearchCopy(SearchText.retry, useEnglish),
        onAction: cubit.loadInitial,
      );
    }
    if (state.status == TourSearchStatus.success && state.items.isEmpty) {
      return _CenteredState(
        icon: Icons.travel_explore,
        title: publicSearchCopy(SearchText.emptyTitle, useEnglish),
        message: cubit.devSearchEnabled
            ? 'Try adjusting the filters.'
            : publicSearchCopy(SearchText.emptyMessage, useEnglish),
        actionLabel: publicSearchCopy(SearchText.resetEmpty, useEnglish),
        onAction: cubit.resetFilters,
      );
    }
    return RefreshIndicator(
      onRefresh: cubit.refresh,
      color: TourSearchPalette.teal,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        itemCount: state.items.length + 2,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.xs,
                bottom: AppSpacing.xxs,
              ),
              child: Text(
                publicSearchCount(state.totalCount, useEnglish),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: TourSearchPalette.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }
          if (index > state.items.length) {
            return _PageNavigation(
              state: state,
              cubit: cubit,
              useEnglish: useEnglish,
            );
          }
          final tour = state.items[index - 1];
          return TourListCard(
            tour: tour,
            useEnglish: useEnglish,
            onTap: () =>
                context.push(AppRoutes.tourDetail(tour.tourId), extra: tour),
          );
        },
      ),
    );
  }
}

class _PageNavigation extends StatelessWidget {
  const _PageNavigation({
    required this.state,
    required this.cubit,
    required this.useEnglish,
  });

  final TourSearchState state;
  final TourSearchCubit cubit;
  final bool useEnglish;

  @override
  Widget build(BuildContext context) {
    if (state.totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: publicSearchCopy(SearchText.previousPage, useEnglish),
          onPressed: state.page > 1
              ? () => cubit.goToPage(state.page - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(publicSearchPage(state.page, state.totalPages, useEnglish)),
        IconButton(
          tooltip: publicSearchCopy(SearchText.nextPage, useEnglish),
          onPressed: state.page < state.totalPages
              ? () => cubit.goToPage(state.page + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// State Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Material(
        color: TourSearchPalette.tealSoft,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          leading: Icon(icon, color: TourSearchPalette.teal),
          title: Text(message),
          trailing: actionLabel == null
              ? null
              : TextButton(onPressed: onAction, child: Text(actionLabel!)),
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: TourSearchPalette.teal),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: TourSearchPalette.teal,
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourSkeletonList extends StatelessWidget {
  const _TourSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TourSearchPalette.cardBorder),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 18, color: TourSearchPalette.line),
            const SizedBox(height: AppSpacing.xs),
            FractionallySizedBox(
              widthFactor: 0.6,
              child: Container(height: 14, color: TourSearchPalette.line),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Container(height: 14, color: TourSearchPalette.line),
                ),
                const SizedBox(width: AppSpacing.xl),
                Container(
                  width: 80,
                  height: 24,
                  decoration: BoxDecoration(
                    color: TourSearchPalette.line,
                    borderRadius: BorderRadius.circular(12),
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
