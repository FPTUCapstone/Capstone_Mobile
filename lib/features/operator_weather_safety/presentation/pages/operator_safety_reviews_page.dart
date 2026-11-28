import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/app_typography.dart';
import 'package:trip_mate_mobile/features/emergency_tour/resources/emergency_copy_vi.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_state.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/widgets/safety_review_status_badge.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/resources/operator_weather_safety_vi.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_coastal_app_bar.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';
import 'package:trip_mate_mobile/shared/widgets/loading_indicator.dart';

typedef _Strings = OperatorWeatherSafetyStringsVi;

class OperatorSafetyReviewsPage extends StatefulWidget {
  const OperatorSafetyReviewsPage({super.key});

  @override
  State<OperatorSafetyReviewsPage> createState() =>
      _OperatorSafetyReviewsPageState();
}

class _OperatorSafetyReviewsPageState extends State<OperatorSafetyReviewsPage> {
  late final OperatorSafetyReviewsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<OperatorSafetyReviewsCubit>();
    _cubit.refresh();
  }

  // Also covers routes opened from outside this page, such as a push tap.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit.setInboxVisible(ModalRoute.isCurrentOf(context) ?? true);
  }

  @override
  void dispose() {
    _cubit.setInboxVisible(false);
    super.dispose();
  }

  Future<void> _open(WeatherSafetyReview review) async {
    await context.push(AppRoutes.operatorSafetyReviewPath(review.id));
    if (!mounted) return;
    await _cubit.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Scaffold(
      backgroundColor: c.canvas,
      appBar: const AppCoastalAppBar(title: _Strings.safetyAlerts),
      body: BlocBuilder<OperatorSafetyReviewsCubit, OperatorSafetyReviewsState>(
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Filters(state: state, onSelected: _cubit.setFilter),
            if (state.isStale)
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: AppAlert(
                  message: _Strings.staleList,
                  type: AppAlertType.warning,
                ),
              ),
            Expanded(child: _body(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, OperatorSafetyReviewsState state) {
    final c = context.tmColors;
    return switch (state.status) {
      OperatorSafetyReviewsStatus.initial ||
      OperatorSafetyReviewsStatus.loading => const LoadingIndicator(),
      OperatorSafetyReviewsStatus.failure => ErrorView(
        retryLabel: _Strings.retry,
        message: state.failure?.viMessage ?? _Strings.loadFailed,
        onRetry: _cubit.refresh,
      ),
      OperatorSafetyReviewsStatus.ready => RefreshIndicator(
        color: c.brandTeal,
        onRefresh: _cubit.refresh,
        child: state.visibleReviews.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: AppSpacing.xl),
                  AppEmptyState(
                    title: _Strings.emptyTitle,
                    message: _Strings.emptyMessage,
                    icon: Icons.shield_outlined,
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: state.visibleReviews.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, index) {
                  final review = state.visibleReviews[index];
                  return _ReviewCard(
                    review: review,
                    onTap: () => _open(review),
                  );
                },
              ),
      ),
    };
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.onSelected});

  final OperatorSafetyReviewsState state;
  final ValueChanged<WeatherSafetyReviewStatus?> onSelected;

  static const _statuses = {
    'pending': WeatherSafetyReviewStatus.pendingAcknowledgement,
    'escalated': WeatherSafetyReviewStatus.escalated,
    'acknowledged': WeatherSafetyReviewStatus.acknowledged,
    'closed': WeatherSafetyReviewStatus.closed,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceCard,
        border: Border(bottom: BorderSide(color: c.borderSubtle)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            ChoiceChip(
              key: const Key('safety-filter-all'),
              label: const Text(_Strings.filterAll),
              selected: state.filter == null,
              onSelected: (_) => onSelected(null),
            ),
            for (final entry in _statuses.entries) ...[
              const SizedBox(width: AppSpacing.xs),
              ChoiceChip(
                key: Key('safety-filter-${entry.key}'),
                label: Text(_Strings.reviewStatus(entry.value)),
                selected: state.filter == entry.value,
                onSelected: (_) => onSelected(entry.value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onTap});

  final WeatherSafetyReview review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.tmColors;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  review.tourTitle,
                  style: TextStyle(
                    fontFamily: AppTypography.displayFont,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, size: 20, color: c.textMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          SafetyReviewStatusBadge(status: review.status),
          if (review.eventType case final event?) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.thunderstorm_outlined, size: 15, color: c.warning),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    [event, ?severityLabel(review.severity)].join(' · '),
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.schedule_outlined, size: 14, color: c.textMuted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${_Strings.deadline}: ${TripFormatters.formatVietnamDateTime(review.acknowledgementDeadlineUtc)}',
                  style: TextStyle(fontSize: 12.5, color: c.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
