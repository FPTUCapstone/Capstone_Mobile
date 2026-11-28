import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendation.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/cubit/tour_recommendations_cubit.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/cubit/tour_recommendations_state.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/resources/tour_recommendations_strings.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/widgets/tour_list_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';

class TourRecommendationsPage extends StatelessWidget {
  const TourRecommendationsPage({this.isDemoMode = false, super.key});

  final bool isDemoMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TourRecommendationsCubit(isDemoMode: isDemoMode)..load(),
      child: const _TourRecommendationsView(),
    );
  }
}

Future<void> _openPreferencesAndRefresh(BuildContext context) async {
  await context.push(AppRoutes.travelerPreferences);
  if (context.mounted) {
    await context.read<TourRecommendationsCubit>().refresh();
  }
}

class _TourRecommendationsView extends StatelessWidget {
  const _TourRecommendationsView();

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final cubit = context.watch<TourRecommendationsCubit>();
    final state = cubit.state;

    return Scaffold(
      backgroundColor: c.canvas,
      appBar: AppCoastalAppBar(
        title: TourRecommendationsStrings.appBarTitle,
        actions: [
          IconButton(
            tooltip: TourRecommendationsStrings.preferencesTooltip,
            icon: const Icon(Icons.tune),
            onPressed: () => _openPreferencesAndRefresh(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: cubit.refresh,
          color: c.brandTeal,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Demo Control Bar (Debug only) ──────────────────────────────
              if (state.isDemoMode && kDebugMode)
                SliverToBoxAdapter(
                  child: _DemoControlsBar(cubit: cubit, state: state),
                ),

              // ── Header Banner ──────────────────────────────────────────────
              const SliverToBoxAdapter(
                child: _RecommendationExplanationBanner(),
              ),

              if (state.errorMessage == TourRecommendationsState.msg127 &&
                  state.recommendations.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: MaterialBanner(
                      backgroundColor: c.errorContainer,
                      content: Text(
                        TourRecommendationsState.msg127,
                        style: TextStyle(color: c.textPrimary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: cubit.refresh,
                          child: const Text(TourRecommendationsStrings.retry),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Main Body based on Status ──────────────────────────────────
              switch (state.status) {
                TourRecommendationsStatus.initial ||
                TourRecommendationsStatus.loading => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: c.brandTeal),
                  ),
                ),

                TourRecommendationsStatus.pendingIntegration =>
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _PendingIntegrationView(),
                  ),

                TourRecommendationsStatus.noPreferences => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NoPreferencesView(
                    message:
                        state.errorMessage ?? TourRecommendationsState.msg183,
                  ),
                ),

                TourRecommendationsStatus.noMatches => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _NoMatchesView(
                    message:
                        state.errorMessage ?? TourRecommendationsState.msg64,
                  ),
                ),

                TourRecommendationsStatus.error => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorView(
                    message:
                        state.errorMessage ?? TourRecommendationsState.msg127,
                    onRetry: cubit.load,
                  ),
                ),

                TourRecommendationsStatus.success => _RecommendationListSliver(
                  recommendations: state.recommendations,
                  currentPage: state.currentPage,
                  totalPages: state.totalPages,
                  totalItems: state.totalItems,
                  cubit: cubit,
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Explanation Banner
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationExplanationBanner extends StatelessWidget {
  const _RecommendationExplanationBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.tealSoftContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.borderSubtle),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome, color: c.brandTeal, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TourRecommendationsStrings.bannerTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    TourRecommendationsStrings.bannerDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  GestureDetector(
                    onTap: () => _openPreferencesAndRefresh(context),
                    child: Text(
                      TourRecommendationsStrings.bannerEditPreferences,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c.brandTeal,
                        decoration: TextDecoration.underline,
                        decorationColor: c.brandTeal,
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Integration View (Production Truthful)
// ─────────────────────────────────────────────────────────────────────────────

class _PendingIntegrationView extends StatelessWidget {
  const _PendingIntegrationView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.tealSoftContainer,
                shape: BoxShape.circle,
                border: Border.all(color: c.borderStrong),
              ),
              child: Icon(Icons.hub_outlined, size: 48, color: c.brandTeal),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              TourRecommendationsStrings.pendingIntegrationTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              TourRecommendationsStrings.pendingIntegrationDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.tourSearch),
              icon: const Icon(Icons.travel_explore),
              label: const Text(TourRecommendationsStrings.exploreAllTours),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _openPreferencesAndRefresh(context),
              icon: const Icon(Icons.tune),
              label: const Text(
                TourRecommendationsStrings.updateTravelPreferences,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// No Preferences View (MSG183)
// ─────────────────────────────────────────────────────────────────────────────

class _NoPreferencesView extends StatelessWidget {
  const _NoPreferencesView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.coralSoftContainer,
                shape: BoxShape.circle,
                border: Border.all(color: c.borderSubtle),
              ),
              child: Icon(
                Icons.bookmark_add_outlined,
                size: 44,
                color: c.brandCoral,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              TourRecommendationsStrings.noPreferencesTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => _openPreferencesAndRefresh(context),
              icon: const Icon(Icons.tune),
              label: const Text(
                TourRecommendationsStrings.setupTravelPreferences,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// No Matches View (MSG64)
// ─────────────────────────────────────────────────────────────────────────────

class _NoMatchesView extends StatelessWidget {
  const _NoMatchesView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: c.borderSubtle),
              ),
              child: Icon(
                Icons.search_off_outlined,
                size: 44,
                color: c.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              TourRecommendationsStrings.noMatchesTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.tourSearch),
              icon: const Icon(Icons.travel_explore),
              label: const Text(TourRecommendationsStrings.exploreAllTours),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => _openPreferencesAndRefresh(context),
              icon: const Icon(Icons.tune),
              label: const Text(TourRecommendationsStrings.adjustPreferences),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error View (MSG127)
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: c.errorContainer,
                shape: BoxShape.circle,
                border: Border.all(color: c.error.withValues(alpha: 0.35)),
              ),
              child: Icon(Icons.cloud_off_outlined, size: 44, color: c.error),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              TourRecommendationsStrings.errorTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text(TourRecommendationsStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success Recommendation List + Pagination
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationListSliver extends StatelessWidget {
  const _RecommendationListSliver({
    required this.recommendations,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.cubit,
  });

  final List<TourRecommendation> recommendations;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final TourRecommendationsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.xs,
                  bottom: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        TourRecommendationsStrings.matchingToursCount(
                          totalItems,
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: c.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      TourRecommendationsStrings.pageIndicator(
                        currentPage,
                        totalPages,
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            final itemIndex = index - 1;
            if (itemIndex < recommendations.length) {
              final rec = recommendations[itemIndex];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TourListCard(
                      tour: rec.tour,
                      matchingScore: rec.matchingScore / 100,
                      onTap: () {
                        context.push(
                          AppRoutes.tourDetail(
                            rec.tour.tourId,
                            demo: cubit.state.isDemoMode,
                          ),
                          extra: rec.tour,
                        );
                      },
                    ),
                    if (rec.matchReasons.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.xs,
                          left: AppSpacing.sm,
                          right: AppSpacing.sm,
                        ),
                        child: Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xxs,
                          children: rec.matchReasons
                              .map(
                                (reason) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.surfaceElevated,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: c.borderSubtle),
                                  ),
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: c.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              );
            }

            // Pagination Controls (CR-01)
            return _PaginationControls(
              currentPage: currentPage,
              totalPages: totalPages,
              onPrevious: currentPage > 1
                  ? () => cubit.loadPage(currentPage - 1)
                  : null,
              onNext: currentPage < totalPages
                  ? () => cubit.loadPage(currentPage + 1)
                  : null,
            );
          },
          childCount: recommendations.length + 2, // header + items + pagination
        ),
      ),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          OutlinedButton.icon(
            key: const Key('rec-prev-page-button'),
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left, size: 18),
            label: const Text(TourRecommendationsStrings.previousPage),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              TourRecommendationsStrings.pageRatio(currentPage, totalPages),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
            ),
          ),
          OutlinedButton.icon(
            key: const Key('rec-next-page-button'),
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text(TourRecommendationsStrings.nextPage),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Demo Controls Bar (Debug Only)
// ─────────────────────────────────────────────────────────────────────────────

class _DemoControlsBar extends StatelessWidget {
  const _DemoControlsBar({required this.cubit, required this.state});

  final TourRecommendationsCubit cubit;
  final TourRecommendationsState state;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Container(
      decoration: BoxDecoration(
        color: c.warningContainer,
        border: Border(
          bottom: BorderSide(color: c.warning.withValues(alpha: 0.35)),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, size: 14, color: c.warning),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  TourRecommendationsStrings.demoControlsTitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: c.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text(
                    TourRecommendationsStrings.demoChipSuccess,
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: state.status == TourRecommendationsStatus.success,
                  onSelected: (_) => cubit.loadDemoPage(1),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text(
                    TourRecommendationsStrings.demoChipNoPreferences,
                    style: TextStyle(fontSize: 11),
                  ),
                  selected:
                      state.status == TourRecommendationsStatus.noPreferences,
                  onSelected: (_) => cubit.simulateNoPreferences(),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text(
                    TourRecommendationsStrings.demoChipNoMatches,
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: state.status == TourRecommendationsStatus.noMatches,
                  onSelected: (_) => cubit.simulateNoMatches(),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text(
                    TourRecommendationsStrings.demoChipError,
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: state.status == TourRecommendationsStatus.error,
                  onSelected: (_) => cubit.simulateError(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
