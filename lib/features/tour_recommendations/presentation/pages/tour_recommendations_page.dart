import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/domain/entities/tour_recommendation.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/cubit/tour_recommendations_cubit.dart';
import 'package:trip_mate_mobile/features/tour_recommendations/presentation/cubit/tour_recommendations_state.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/theme/tour_search_palette.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/widgets/tour_list_card.dart';

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

class _TourRecommendationsView extends StatelessWidget {
  const _TourRecommendationsView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<TourRecommendationsCubit>();
    final state = cubit.state;

    return Scaffold(
      backgroundColor: TourSearchPalette.background,
      appBar: AppBar(
        title: const Text('Gợi ý Tour dành cho bạn'),
        backgroundColor: Colors.white,
        foregroundColor: TourSearchPalette.navy,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sở thích du lịch',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(AppRoutes.travelerPreferences),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: cubit.refresh,
          color: TourSearchPalette.teal,
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

              // ── Main Body based on Status ──────────────────────────────────
              switch (state.status) {
                TourRecommendationsStatus.initial ||
                TourRecommendationsStatus.loading => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: TourSearchPalette.teal,
                    ),
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
                        state.errorMessage ?? TourRecommendationsState.msg28,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF16A34A), size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đề xuất cá nhân hoá (> 80% phù hợp)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF15803D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Các tour được chọn lọc tự động dựa trên thẻ sở thích du lịch và lịch trình yêu thích của bạn.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.travelerPreferences),
                    child: const Text(
                      'Chỉnh sửa sở thích du lịch →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                        decoration: TextDecoration.underline,
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Icon(
                Icons.hub_outlined,
                size: 48,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tính năng gợi ý tour đang được tích hợp',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Hệ thống AI phân tích và đề xuất tour dựa trên sở thích đang chờ kết nối dịch vụ máy chủ Backend. Bạn có thể khám phá toàn bộ danh sách tour hoặc cập nhật hồ sơ sở thích ngay bây giờ.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: TourSearchPalette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.tourSearch),
              icon: const Icon(Icons.travel_explore),
              label: const Text('Khám phá tất cả Tour'),
              style: FilledButton.styleFrom(
                backgroundColor: TourSearchPalette.teal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.travelerPreferences),
              icon: const Icon(Icons.tune),
              label: const Text('Cập nhật sở thích du lịch'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// No Preferences View (MSG28)
// ─────────────────────────────────────────────────────────────────────────────

class _NoPreferencesView extends StatelessWidget {
  const _NoPreferencesView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bookmark_add_outlined,
              size: 52,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Chưa thiết lập sở thích',
              style: theme.textTheme.titleMedium?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: TourSearchPalette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.travelerPreferences),
              icon: const Icon(Icons.tune),
              label: const Text('Thiết lập sở thích du lịch'),
              style: FilledButton.styleFrom(
                backgroundColor: TourSearchPalette.teal,
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_outlined,
              size: 52,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Không có tour đạt mức phù hợp > 80%',
              style: theme.textTheme.titleMedium?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: TourSearchPalette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.tourSearch),
              icon: const Icon(Icons.travel_explore),
              label: const Text('Khám phá tất cả Tour'),
              style: FilledButton.styleFrom(
                backgroundColor: TourSearchPalette.teal,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.travelerPreferences),
              icon: const Icon(Icons.tune),
              label: const Text('Điều chỉnh sở thích'),
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
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 52,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Không thể tải gợi ý tour',
              style: theme.textTheme.titleMedium?.copyWith(
                color: TourSearchPalette.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: TourSearchPalette.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: TourSearchPalette.teal,
              ),
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
                        'Tìm thấy $totalItems tour phù hợp',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: TourSearchPalette.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Trang $currentPage / $totalPages',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: TourSearchPalette.muted,
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
                      matchingScore: rec.matchingScore,
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
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    reason,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF475569),
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
                  ? () => cubit.loadDemoPage(currentPage - 1)
                  : null,
              onNext: currentPage < totalPages
                  ? () => cubit.loadDemoPage(currentPage + 1)
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
            label: const Text('Trang trước'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              '$currentPage / $totalPages',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: TourSearchPalette.navy,
              ),
            ),
          ),
          OutlinedButton.icon(
            key: const Key('rec-next-page-button'),
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, size: 18),
            label: const Text('Trang sau'),
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
    return Container(
      color: const Color(0xFFFEF3C7),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bug_report, size: 14, color: Color(0xFFB45309)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'DEMO SIMULATION CONTROLS (Debug Mode Only)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
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
                    'Thành công (>80%)',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: state.status == TourRecommendationsStatus.success,
                  onSelected: (_) => cubit.loadDemoPage(1),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text(
                    'Chưa có sở thích (MSG28)',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected:
                      state.status == TourRecommendationsStatus.noPreferences,
                  onSelected: (_) => cubit.simulateNoPreferences(),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text(
                    'Không khớp >80% (MSG64)',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: state.status == TourRecommendationsStatus.noMatches,
                  onSelected: (_) => cubit.simulateNoMatches(),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text(
                    'Lỗi kết nối (MSG127)',
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
