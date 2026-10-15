import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_summary.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/my_trips_state.dart';

/// The Traveler's trips: every itinerary they planned or joined, leading to the
/// itinerary detail where navigation starts.
final class MyTripsPage extends StatelessWidget {
  const MyTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyTripsCubit, MyTripsState>(
      builder: (context, state) {
        final cubit = context.read<MyTripsCubit>();
        return RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _Actions(onReturned: cubit.load),
              const SizedBox(height: AppSpacing.lg),
              Text('My trips', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              ..._content(context, state, cubit),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _content(
    BuildContext context,
    MyTripsState state,
    MyTripsCubit cubit,
  ) {
    if (state.trips.isEmpty) {
      return switch (state.status) {
        // Nothing animates before the first load: the tab is built offstage.
        MyTripsStatus.initial => const [],
        MyTripsStatus.loading => const [
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
        MyTripsStatus.failure => [
          Text(state.message ?? 'Your trips are unavailable right now.'),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: cubit.load,
              child: const Text('Try again'),
            ),
          ),
        ],
        MyTripsStatus.ready => const [
          Text('No trips yet. Create an itinerary to plan your first trip.'),
        ],
      };
    }
    return [
      if (state.status == MyTripsStatus.failure && state.message != null)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            state.message!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      for (final trip in state.trips)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _TripCard(
            trip: trip,
            onTap: () async {
              await context.push(
                AppRoutes.itineraryDetailPath(trip.itineraryId),
              );
              if (context.mounted) await cubit.load();
            },
          ),
        ),
      if (state.hasMore)
        Center(
          child: state.isLoadingMore
              ? const CircularProgressIndicator()
              : TextButton(
                  onPressed: cubit.loadMore,
                  child: const Text('Show more trips'),
                ),
        ),
    ];
  }
}

final class _Actions extends StatelessWidget {
  const _Actions({required this.onReturned});

  final Future<void> Function() onReturned;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: () async {
          await context.push(AppRoutes.createItinerary);
          if (context.mounted) await onReturned();
        },
        icon: const Icon(Icons.auto_awesome_outlined),
        label: const Text('Create an itinerary'),
      ),
      const SizedBox(height: AppSpacing.xs),
      OutlinedButton.icon(
        onPressed: () async {
          await context.push(AppRoutes.joinTravelGroup);
          if (context.mounted) await onReturned();
        },
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Join travel group'),
      ),
    ],
  );
}

final class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap});

  final ItinerarySummary trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = trip.title?.trim();
    final schedule = tripSchedule(trip.validFrom, trip.validTo);
    return Card(
      key: ValueKey('trip_${trip.itineraryId}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title == null || title.isEmpty
                          ? 'Untitled itinerary'
                          : title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _Tag(label: trip.status),
                  if (trip.isTripInProgress)
                    const _Tag(
                      label: 'Trip in progress',
                      color: AppColors.success,
                    ),
                  if (!trip.canManage) const _Tag(label: 'Shared with you'),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                [
                  ?schedule,
                  trip.stopCount == 1 ? '1 stop' : '${trip.stopCount} stops',
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone),
        ),
      ),
    );
  }
}
