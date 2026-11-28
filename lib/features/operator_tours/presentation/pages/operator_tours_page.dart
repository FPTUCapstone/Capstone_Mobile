import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/operator_tours_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_filter_chip_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';
import 'package:trip_mate_mobile/shared/widgets/status_badge.dart';

String tourStatusLabel(TourPackageStatus status) => switch (status) {
  TourPackageStatus.draft => 'Bản nháp',
  TourPackageStatus.pending => 'Chờ duyệt',
  TourPackageStatus.approved => 'Đã duyệt (chưa đăng)',
  TourPackageStatus.rejected => 'Bị từ chối',
  TourPackageStatus.published => 'Đang mở bán',
  TourPackageStatus.inactive => 'Ngừng hoạt động',
};

String effectiveTourStatusLabel(
  TourPackageStatus status,
  DateTime? publishedAtUtc,
) => isLivePublishedTour(status, publishedAtUtc)
    ? tourStatusLabel(TourPackageStatus.published)
    : tourStatusLabel(status);

StatusBadgeType _tourBadgeType(
  TourPackageStatus status,
  DateTime? publishedAtUtc,
) {
  if (isLivePublishedTour(status, publishedAtUtc)) {
    return StatusBadgeType.success;
  }
  return switch (status) {
    TourPackageStatus.published => StatusBadgeType.success,
    TourPackageStatus.approved => StatusBadgeType.info,
    TourPackageStatus.pending => StatusBadgeType.warning,
    TourPackageStatus.rejected => StatusBadgeType.error,
    TourPackageStatus.draft ||
    TourPackageStatus.inactive => StatusBadgeType.neutral,
  };
}

/// The operator's tour packages: filter by status, open one to resume or view it.
///
/// Follows Canonical Template T4 (Discovery / Filtered List Page).
final class OperatorToursPage extends StatelessWidget {
  const OperatorToursPage({super.key});

  Future<void> _open(BuildContext context, String location) async {
    await context.push<Object?>(location);
    if (context.mounted) await context.read<OperatorToursCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: const AppCoastalAppBar(title: 'Gói tour của tôi'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.actionPrimary,
        foregroundColor: c.textOnBrand,
        elevation: 2,
        onPressed: () => _open(context, AppRoutes.createTourPackage),
        icon: const Icon(Icons.add),
        label: const Text('Tạo gói tour'),
      ),
      body: SafeArea(
        child: BlocBuilder<OperatorToursCubit, OperatorToursState>(
          builder: (context, state) => Column(
            children: [
              AppFilterChipBar<TourPackageStatus?>(
                showBottomBorder: true,
                selectedValue: state.filter,
                onSelected: (status) =>
                    context.read<OperatorToursCubit>().load(filter: status),
                options: [
                  const AppFilterOption<TourPackageStatus?>(
                    value: null,
                    label: 'Tất cả',
                  ),
                  for (final status in TourPackageStatus.values)
                    AppFilterOption<TourPackageStatus?>(
                      value: status,
                      label: tourStatusLabel(status),
                    ),
                ],
              ),
              Expanded(
                child: _Body(state: state, onOpen: _open),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _Body extends StatelessWidget {
  const _Body({required this.state, required this.onOpen});
  final OperatorToursState state;
  final Future<void> Function(BuildContext, String) onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    switch (state.status) {
      case OperatorToursStatus.loading:
        return Center(child: CircularProgressIndicator(color: c.brandTeal));
      case OperatorToursStatus.failure:
        return ErrorView(
          message:
              state.failure?.message ??
              'Không thể tải danh sách gói tour của bạn.',
          retryLabel: 'Thử lại',
          onRetry: () => context.read<OperatorToursCubit>().refresh(),
        );
      case OperatorToursStatus.ready:
        if (state.items.isEmpty) {
          return const AppEmptyState(
            icon: Icons.tour_outlined,
            title: 'Chưa có gói tour nào.',
            message: 'Hãy tạo gói tour đầu tiên để bắt đầu đón du khách.',
          );
        }
        return RefreshIndicator(
          color: c.brandTeal,
          onRefresh: () => context.read<OperatorToursCubit>().refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              96,
            ),
            children: [
              for (var i = 0; i < state.items.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.sm),
                _OperatorTourListItem(
                  tour: state.items[i],
                  onTap: () => onOpen(
                    context,
                    AppRoutes.editTourPackagePath(state.items[i].id),
                  ),
                ),
              ],
              if (state.failure != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppAlert(
                  type: AppAlertType.error,
                  message: state.failure!.message,
                ),
              ],
              if (state.hasMore) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: state.loadingMore
                      ? null
                      : () => context.read<OperatorToursCubit>().loadMore(),
                  child: Text(state.loadingMore ? 'Đang tải...' : 'Tải thêm'),
                ),
              ],
            ],
          ),
        );
    }
  }
}

final class _OperatorTourListItem extends StatelessWidget {
  const _OperatorTourListItem({required this.tour, required this.onTap});

  final TourPackageSummary tour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    final statusLabel = effectiveTourStatusLabel(
      tour.status,
      tour.publishedAtUtc,
    );
    final metadataLine = [
      'v${tour.versionNo}',
      statusLabel,
      if (tour.destination.isNotEmpty) tour.destination,
      '${tour.durationDays} ngày',
      '${tour.basePrice} VND',
      if (tour.upcomingDepartureCount != null)
        '${tour.upcomingDepartureCount} lịch khởi hành sắp tới',
    ].join(' · ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      tour.title,
                      style: TextStyle(
                        fontFamily: AppTypography.uiFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    StatusBadge(
                      label: statusLabel,
                      type: _tourBadgeType(tour.status, tour.publishedAtUtc),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  metadataLine,
                  style: TextStyle(
                    fontFamily: AppTypography.uiFont,
                    fontSize: 12.5,
                    height: 1.4,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right_rounded, color: c.textMuted),
        ],
      ),
    );
  }
}
