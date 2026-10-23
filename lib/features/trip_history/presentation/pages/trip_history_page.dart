import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_records_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_records_state.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/trip_history_card.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/trip_history_filters_bar.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/trip_record_detail_sheet.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/loading_indicator.dart';

/// UC-32 View Trip History. Reads the TM-78 API through [TripRecordsCubit];
/// the screen never invents or fills in a record.
class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({this.isDemoMode = false, super.key});

  final bool isDemoMode;

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    TripStatus.upcoming,
    TripStatus.completed,
    TripStatus.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabs.indexOf(
      context.read<TripRecordsCubit>().state.selectedTab,
    );
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex.clamp(0, _tabs.length - 1),
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final cubit = context.read<TripRecordsCubit>();
    if (cubit.state.selectedTab != _tabs[_tabController.index]) {
      cubit.switchTab(_tabs[_tabController.index]);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _showEticketNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(TripHistoryStringsEn.noticeEticketPending)),
    );
  }

  void _showDetail(
    BuildContext context,
    TripRecord record, {
    bool highlightRefund = false,
  }) {
    TripRecordDetailSheet.show(
      context,
      record: record,
      isDemo: widget.isDemoMode,
      highlightRefund: highlightRefund,
    );
  }

  /// Refund tracking is the live refund-progress screen for the real booking.
  /// Demo records carry made-up ids that must never reach the refund API, so in
  /// demo mode the refund is shown in the detail sheet instead.
  void _openRefund(BuildContext context, TripRecord record) {
    if (widget.isDemoMode || record is! BookingTripRecord) {
      _showDetail(context, record, highlightRefund: true);
      return;
    }
    context.push(AppRoutes.bookingRefund('${record.reviewableRecord.id}'));
  }

  /// Write review and View review both open the canonical review of the booking
  /// the backend named in `reviewableRecord`.
  Future<void> _openReview(
    BuildContext context,
    BookingTripRecord record,
  ) async {
    final cubit = context.read<TripRecordsCubit>();
    final reviewable = record.reviewableRecord;
    final result = await context.push<bool>(
      AppRoutes.canonicalTripReview(reviewable.wireKind, reviewable.id),
    );
    if (result == true && mounted) {
      await cubit.retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(TripHistoryStringsEn.tripHistoryTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: TripHistoryStringsEn.tabUpcoming),
            Tab(text: TripHistoryStringsEn.tabCompleted),
            Tab(text: TripHistoryStringsEn.tabCancelled),
          ],
        ),
      ),
      body: BlocConsumer<TripRecordsCubit, TripRecordsState>(
        listener: (context, state) {
          final tabIndex = _tabs.indexOf(state.selectedTab);
          if (tabIndex != -1 && _tabController.index != tabIndex) {
            _tabController.animateTo(tabIndex);
          }
        },
        builder: (context, state) {
          final cubit = context.read<TripRecordsCubit>();

          return Column(
            children: [
              const SizedBox(height: AppSpacing.xs),
              TripHistoryFiltersBar(
                selectedTripType: state.tripType,
                startDate: state.startDate,
                endDate: state.endDate,
                validationError: state.validationError,
                onTripTypeChanged: cubit.setTripType,
                onDateRangeSelected: cubit.setDateRange,
                onClearFilters: cubit.clearFilters,
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(child: _buildBody(context, state, cubit)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TripRecordsState state,
    TripRecordsCubit cubit,
  ) {
    if (state.isLoading || state.status == TripRecordsStatus.initial) {
      return const Center(child: LoadingIndicator());
    }

    if (state.isFailure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppAlert(
                message:
                    state.errorMessage ??
                    TripHistoryStringsEn.errorMessageGeneric,
                type: AppAlertType.error,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: cubit.retry,
                icon: const Icon(Icons.refresh),
                label: const Text(TripHistoryStringsEn.actionRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.history_toggle_off_outlined,
                size: 56,
                color: AppColors.muted,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                TripHistoryStringsEn.emptyListMessage,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    final summary = state.summary;
    return Column(
      children: [
        if (summary != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xxs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${TripHistoryStringsEn.summaryCompletedTrips(summary.totalCompletedTrips)}'
                ' · ${TripHistoryStringsEn.summaryVisitedPois(summary.totalVisitedPois)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              return TripHistoryCard(
                record: state.items[index],
                onViewEticket: (_) => _showEticketNotice(context),
                onWriteReview: (r) => _openReview(context, r),
                onViewReview: (r) => _openReview(context, r),
                onViewRefund: (r) => _openRefund(context, r),
                onViewDetails: (r) => _showDetail(context, r),
              );
            },
          ),
        ),
        _buildPaginationBar(context, state, cubit),
      ],
    );
  }

  Widget _buildPaginationBar(
    BuildContext context,
    TripRecordsState state,
    TripRecordsCubit cubit,
  ) {
    if (state.totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: state.hasPreviousPage
                ? () => cubit.goToPage(state.page - 1)
                : null,
            child: const Text(TripHistoryStringsEn.paginationPrevious),
          ),
          Text(
            TripHistoryStringsEn.formatPagination(state.page, state.totalPages),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          OutlinedButton(
            onPressed: state.hasNextPage
                ? () => cubit.goToPage(state.page + 1)
                : null,
            child: const Text(TripHistoryStringsEn.paginationNext),
          ),
        ],
      ),
    );
  }
}
