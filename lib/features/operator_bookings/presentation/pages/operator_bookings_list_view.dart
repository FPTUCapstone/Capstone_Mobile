import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_bookings_cubit.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_bookings_state.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/widgets/operator_booking_card.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/widgets/operator_bookings_filter_sheet.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/widgets/operator_bookings_summary_strip.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';
import 'package:trip_mate_mobile/features/operator_bookings/utils/operator_booking_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';
import 'package:trip_mate_mobile/shared/widgets/app_empty_state.dart';
import 'package:trip_mate_mobile/shared/widgets/app_shimmer.dart';

/// The Tour Operator's customer bookings (UC-40, screen #84): the body of the "Bookings" tab. It needs an
/// [OperatorBookingsCubit] above it and read-only: opening a card shows the detail (#85).
class OperatorBookingsListView extends StatefulWidget {
  const OperatorBookingsListView({
    this.isDemoMode = false,
    this.pickDate = pickOperatorBookingDate,
    super.key,
  });

  /// Shows the demo banner; the data itself comes from the repository the dependency injection chose.
  final bool isDemoMode;

  /// Replaceable in tests; the default opens the Material date picker.
  final OperatorBookingDatePicker pickDate;

  @override
  State<OperatorBookingsListView> createState() =>
      _OperatorBookingsListViewState();
}

class _OperatorBookingsListViewState extends State<OperatorBookingsListView> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.text = context.read<OperatorBookingsCubit>().state.keyword ?? '';
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters(OperatorBookingsCubit cubit) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider<OperatorBookingsCubit>.value(
        value: cubit,
        child: OperatorBookingsFilterSheet(pickDate: widget.pickDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OperatorBookingsCubit>();
    return Column(
      children: [
        if (widget.isDemoMode) const _DemoBanner(),
        Expanded(
          child: BlocBuilder<OperatorBookingsCubit, OperatorBookingsState>(
            builder: (context, state) => RefreshIndicator(
              onRefresh: cubit.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    sliver: SliverToBoxAdapter(
                      child: _Header(
                        state: state,
                        search: _search,
                        onSearch: cubit.search,
                        onSelectStatus: cubit.selectStatus,
                        onOpenFilters: () => _openFilters(cubit),
                      ),
                    ),
                  ),
                  ..._body(context, state, cubit),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _body(
    BuildContext context,
    OperatorBookingsState state,
    OperatorBookingsCubit cubit,
  ) {
    const horizontal = EdgeInsets.symmetric(horizontal: AppSpacing.md);

    if (state.isLoading && state.items.isEmpty) {
      return const [
        SliverPadding(
          padding: horizontal,
          sliver: SliverToBoxAdapter(child: _LoadingPlaceholder()),
        ),
      ];
    }

    if (state.isFailure) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _FailureBody(
            message:
                state.errorMessage ?? OperatorBookingsStringsEn.systemError,
            onRetry: state.canRetry ? cubit.retry : null,
          ),
        ),
      ];
    }

    if (state.items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            icon: Icons.book_online_outlined,
            title: OperatorBookingsStringsEn.emptyTitle,
            message: OperatorBookingsStringsEn.noRecords,
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: horizontal,
        sliver: SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
          itemBuilder: (context, index) {
            final booking = state.items[index];
            return OperatorBookingCard(
              booking: booking,
              onTap: () => context.push(
                AppRoutes.operatorBookingPath(
                  booking.bookingId,
                  isDemo: widget.isDemoMode,
                ),
                extra: booking,
              ),
            );
          },
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.md),
        sliver: SliverToBoxAdapter(
          child: _Footer(state: state, onLoadMore: cubit.loadMore),
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.search,
    required this.onSearch,
    required this.onSelectStatus,
    required this.onOpenFilters,
  });

  final OperatorBookingsState state;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final ValueChanged<OperatorBookingStatus?> onSelectStatus;
  final VoidCallback onOpenFilters;

  bool get _hasSheetFilters =>
      state.tourId != null ||
      state.departureFrom != null ||
      state.departureTo != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OperatorBookingsSummaryStrip(summary: state.summary),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: search,
                textInputAction: TextInputAction.search,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    OperatorBookingsQuery.maxKeywordLength,
                  ),
                ],
                onSubmitted: onSearch,
                decoration: InputDecoration(
                  hintText: OperatorBookingsStringsEn.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.filledTonal(
              tooltip: OperatorBookingsStringsEn.filtersButton,
              onPressed: onOpenFilters,
              icon: Badge(
                isLabelVisible: _hasSheetFilters,
                smallSize: 8,
                child: const Icon(Icons.filter_list),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip(
                OperatorBookingsStringsEn.statusAll,
                selected: state.selectedStatus == null,
                onSelected: () => onSelectStatus(null),
              ),
              for (final status in OperatorBookingStatus.values)
                _chip(
                  OperatorBookingFormatters.statusLabel(status),
                  selected: state.selectedStatus == status,
                  onSelected: () => onSelectStatus(status),
                ),
            ],
          ),
        ),
        if (state.validationError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              state.validationError!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _chip(
    String label, {
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xxs),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onLoadMore});

  final OperatorBookingsState state;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (state.loadMoreError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              state.loadMoreError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        if (state.hasMore)
          OutlinedButton(
            onPressed: state.loadingMore ? null : onLoadMore,
            child: Text(
              state.loadingMore
                  ? OperatorBookingsStringsEn.loadingMore
                  : OperatorBookingsStringsEn.loadMore,
            ),
          ),
      ],
    );
  }
}

class _FailureBody extends StatelessWidget {
  const _FailureBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: OperatorBookingsStringsEn.retry,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('operator-bookings-loading'),
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppShimmer(
              child: Container(
                height: 132,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      color: const Color(0xFFFEF3C7),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              OperatorBookingsStringsEn.demoBanner,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
