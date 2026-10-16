import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_detail.dart';
import 'package:trip_mate_mobile/features/operator_tours/presentation/cubit/operator_tours_cubit.dart';

String tourStatusLabel(TourPackageStatus status) => switch (status) {
  TourPackageStatus.draft => 'Draft',
  TourPackageStatus.pending => 'Pending review',
  TourPackageStatus.approved => 'Approved (not published)',
  TourPackageStatus.rejected => 'Rejected',
  TourPackageStatus.published => 'Published',
  TourPackageStatus.inactive => 'Inactive',
};

/// The operator's tour packages: filter by status, open one to resume or view it.
final class OperatorToursPage extends StatelessWidget {
  const OperatorToursPage({super.key});

  Future<void> _open(BuildContext context, String location) async {
    await context.push<Object?>(location);
    if (context.mounted) await context.read<OperatorToursCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My tour packages')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _open(context, AppRoutes.createTourPackage),
      icon: const Icon(Icons.add),
      label: const Text('Create tour package'),
    ),
    body: SafeArea(
      child: BlocBuilder<OperatorToursCubit, OperatorToursState>(
        builder: (context, state) => Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: state.filter == null,
                    onSelected: () => context.read<OperatorToursCubit>().load(),
                  ),
                  for (final status in TourPackageStatus.values)
                    _FilterChip(
                      label: tourStatusLabel(status),
                      selected: state.filter == status,
                      onSelected: () => context.read<OperatorToursCubit>().load(
                        filter: status,
                      ),
                    ),
                ],
              ),
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

final class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.xs),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
}

final class _Body extends StatelessWidget {
  const _Body({required this.state, required this.onOpen});
  final OperatorToursState state;
  final Future<void> Function(BuildContext, String) onOpen;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case OperatorToursStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case OperatorToursStatus.failure:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.failure?.message ??
                      'Could not load your tour packages.',
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () => context.read<OperatorToursCubit>().refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      case OperatorToursStatus.ready:
        if (state.items.isEmpty) {
          return const Center(child: Text('No tour packages yet.'));
        }
        return RefreshIndicator(
          onRefresh: () => context.read<OperatorToursCubit>().refresh(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final tour in state.items)
                ListTile(
                  title: Text(tour.title),
                  subtitle: Text(
                    [
                      tourStatusLabel(tour.status),
                      if (tour.destination.isNotEmpty) tour.destination,
                      '${tour.durationDays} day(s)',
                      '${tour.basePrice} VND',
                    ].join(' · '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      onOpen(context, AppRoutes.editTourPackagePath(tour.id)),
                ),
              if (state.failure != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(state.failure!.message),
                ),
              if (state.hasMore)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: OutlinedButton(
                    onPressed: state.loadingMore
                        ? null
                        : () => context.read<OperatorToursCubit>().loadMore(),
                    child: Text(state.loadingMore ? 'Loading...' : 'Load more'),
                  ),
                ),
            ],
          ),
        );
    }
  }
}
