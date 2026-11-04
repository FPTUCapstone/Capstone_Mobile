import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_state.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/widgets/safety_review_status_badge.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/resources/operator_weather_safety_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/error_view.dart';
import 'package:trip_mate_mobile/shared/widgets/loading_indicator.dart';

typedef _Strings = OperatorWeatherSafetyStringsEn;

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(_Strings.safetyAlerts)),
    body: BlocBuilder<OperatorSafetyReviewsCubit, OperatorSafetyReviewsState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Filters(state: state, onSelected: _cubit.setFilter),
          if (state.isStale)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppAlert(
                message: _Strings.staleList,
                type: AppAlertType.warning,
              ),
            ),
          Expanded(child: _body(state)),
        ],
      ),
    ),
  );

  Widget _body(OperatorSafetyReviewsState state) => switch (state.status) {
    OperatorSafetyReviewsStatus.initial ||
    OperatorSafetyReviewsStatus.loading => const LoadingIndicator(),
    OperatorSafetyReviewsStatus.failure => ErrorView(
      message: state.failure?.message ?? _Strings.loadFailed,
      onRetry: _cubit.refresh,
    ),
    OperatorSafetyReviewsStatus.ready => RefreshIndicator(
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
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, index) {
                final review = state.visibleReviews[index];
                return _ReviewCard(review: review, onTap: () => _open(review));
              },
            ),
    ),
  };
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
  Widget build(BuildContext context) => SingleChildScrollView(
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
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onTap});

  final WeatherSafetyReview review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          review.tourTitle,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        SafetyReviewStatusBadge(status: review.status),
        if (review.eventType case final event?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            [event, ?review.severity].join(' · '),
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          '${_Strings.deadline}: ${TripFormatters.formatVietnamDateTime(review.acknowledgementDeadlineUtc)}',
          style: const TextStyle(color: AppColors.muted),
        ),
      ],
    ),
  );
}
