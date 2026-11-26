import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/app/theme/coastal_palette.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/presentation/cubit/traveler_emergency_notices_cubit.dart';
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

  /// Null in demo mode, which never reaches the Backend.
  late final TravelerEmergencyNoticesCubit? _notices = widget.isDemoMode
      ? null
      : locateOptional<TravelerEmergencyNoticesCubit>();

  @override
  void initState() {
    super.initState();
    unawaited(_notices?.refresh());
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

  /// UC-29: the e-ticket opens by `actions.ticketId`, never the booking id.
  /// Demo records carry made-up ids that must never reach the ticket API.
  void _openEticket(BuildContext context, TripRecord record) {
    final ticketId = record.actions.ticketId;
    if (widget.isDemoMode || ticketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(TripHistoryStringsEn.noticeEticketDemo)),
      );
      return;
    }
    context.push(AppRoutes.eTicket(ticketId));
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
    final p = CoastalPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hairline = isDark ? p.border : const Color(0xFFEDEAE1);
    final segmentBg = isDark ? p.canvas : const Color(0xFFEDEAE1);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        titleSpacing: 4,
        title: Text(
          TripHistoryStringsEn.tripHistoryTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: p.ink,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: TripHistoryStringsEn.tooltipMyComplaints,
              child: TextButton(
                onPressed: () => context.push(AppRoutes.myPostTripComplaints),
                style: TextButton.styleFrom(
                  foregroundColor: p.secondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: const Size(44, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  TripHistoryStringsEn.actionMyComplaints,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: hairline),
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
              DecoratedBox(
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border(bottom: BorderSide(color: hairline)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: segmentBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: p.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          splashBorderRadius: BorderRadius.circular(9),
                          labelColor: p.onPrimary,
                          unselectedLabelColor: p.secondary,
                          labelPadding: EdgeInsets.zero,
                          labelStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: const [
                            Tab(text: TripHistoryStringsEn.tabUpcoming),
                            Tab(text: TripHistoryStringsEn.tabCompleted),
                            Tab(text: TripHistoryStringsEn.tabCancelled),
                          ],
                        ),
                      ),
                    ),
                    TripHistoryFiltersBar(
                      selectedTripType: state.tripType,
                      startDate: state.startDate,
                      endDate: state.endDate,
                      validationError: state.validationError,
                      onTripTypeChanged: cubit.setTripType,
                      onDateRangeSelected: cubit.setDateRange,
                      onClearFilters: cubit.clearFilters,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              Expanded(child: _buildBody(context, state, cubit, p)),
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
    CoastalPalette p,
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
                style: FilledButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh, size: 18),
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
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.luggage_outlined,
                  size: 40,
                  color: p.secondary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  TripHistoryStringsEn.emptyListMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: p.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final summary = state.summary;
    return Column(
      children: [
        if (summary != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${TripHistoryStringsEn.summaryCompletedTrips(summary.totalCompletedTrips)}'
                ' · ${TripHistoryStringsEn.summaryVisitedPois(summary.totalVisitedPois)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: p.secondary,
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 20),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final record = state.items[index];
              Widget card(bool hasNotice) => TripHistoryCard(
                record: record,
                onViewEticket: (record) => _openEticket(context, record),
                onWriteReview: (r) => _openReview(context, r),
                onViewReview: (r) => _openReview(context, r),
                onViewRefund: (r) => _openRefund(context, r),
                onViewDetails: (r) => _showDetail(context, r),
                hasEmergencyNotice: hasNotice,
                onViewEmergencyNotice: widget.isDemoMode
                    ? null
                    : (r) => context.push(
                        AppRoutes.travelerEmergency(r.reviewableRecord.id),
                      ),
              );
              final notices = _notices;
              if (notices == null || record is! BookingTripRecord) {
                return card(false);
              }
              return BlocSelector<
                TravelerEmergencyNoticesCubit,
                TravelerEmergencyNoticesState,
                bool
              >(
                bloc: notices,
                selector: (state) =>
                    state.hasNoticeFor(record.reviewableRecord.id),
                builder: (_, hasNotice) => card(hasNotice),
              );
            },
          ),
        ),
        _buildPaginationBar(context, state, cubit, p),
      ],
    );
  }

  Widget _buildPaginationBar(
    BuildContext context,
    TripRecordsState state,
    TripRecordsCubit cubit,
    CoastalPalette p,
  ) {
    if (state.totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: state.hasPreviousPage
                ? () => cubit.goToPage(state.page - 1)
                : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.ink,
              side: BorderSide(color: p.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(TripHistoryStringsEn.paginationPrevious),
          ),
          Text(
            TripHistoryStringsEn.formatPagination(state.page, state.totalPages),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: p.ink,
            ),
          ),
          OutlinedButton(
            onPressed: state.hasNextPage
                ? () => cubit.goToPage(state.page + 1)
                : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.ink,
              side: BorderSide(color: p.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(TripHistoryStringsEn.paginationNext),
          ),
        ],
      ),
    );
  }
}
