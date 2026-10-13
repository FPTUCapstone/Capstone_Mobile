import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/app/theme/app_spacing.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_history_item.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_cubit.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/cubit/trip_history_state.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/refund_status_dialog.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/trip_history_card.dart';
import 'package:trip_mate_mobile/features/trip_history/presentation/widgets/trip_history_filters_bar.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';
import 'package:trip_mate_mobile/features/trip_history/utils/trip_formatters.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/loading_indicator.dart';

class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({this.initialTab = TripStatus.upcoming, super.key});

  final TripStatus initialTab;

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
    final initialIndex = _tabs.indexOf(widget.initialTab).clamp(0, 2);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final cubit = context.read<TripHistoryCubit>();
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

  void _showBookingDetailsDialog(BuildContext context, TripHistoryItem item) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text(TripHistoryStringsEn.detailsDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            const SizedBox(height: AppSpacing.xs),
            _detailRow(TripHistoryStringsEn.labelBookingCode, item.bookingCode),
            _detailRow(
              TripHistoryStringsEn.labelDepartureDate,
              TripFormatters.formatVietnamDate(item.departureDate),
            ),
            _detailRow(
              TripHistoryStringsEn.labelParticipants,
              TripHistoryStringsEn.formatParticipants(item.participantsCount),
            ),
            _detailRow(
              TripHistoryStringsEn.labelTotalAmount,
              TripFormatters.formatVnd(item.totalAmount),
            ),
            if (item.providerName != null)
              _detailRow(
                TripHistoryStringsEn.detailsProvider,
                item.providerName!,
              ),
            if (item.location != null)
              _detailRow(TripHistoryStringsEn.detailsLocation, item.location!),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(TripHistoryStringsEn.actionClose),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _navigateToReview(BuildContext context, TripHistoryItem item) {
    context.push(AppRoutes.tripReview(item.id), extra: item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(TripHistoryStringsEn.tripHistoryTitle),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            context.read<TripHistoryCubit>().switchTab(_tabs[index]);
          },
          tabs: const [
            Tab(text: TripHistoryStringsEn.tabUpcoming),
            Tab(text: TripHistoryStringsEn.tabCompleted),
            Tab(text: TripHistoryStringsEn.tabCancelled),
          ],
        ),
      ),
      body: BlocConsumer<TripHistoryCubit, TripHistoryState>(
        listener: (context, state) {
          final tabIndex = _tabs.indexOf(state.selectedTab);
          if (tabIndex != -1 && _tabController.index != tabIndex) {
            _tabController.animateTo(tabIndex);
          }
        },
        builder: (context, state) {
          final cubit = context.read<TripHistoryCubit>();

          return Column(
            children: [
              const SizedBox(height: AppSpacing.xs),
              TripHistoryFiltersBar(
                selectedTripType: state.selectedTripType,
                startDate: state.startDate,
                endDate: state.endDate,
                validationError: state.validationError,
                onTripTypeChanged: cubit.setTripType,
                onDateRangeSelected: cubit.setDateRange,
                onClearFilters: cubit.clearDateRange,
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
    TripHistoryState state,
    TripHistoryCubit cubit,
  ) {
    if (state.isLoading) {
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

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              return TripHistoryCard(
                item: item,
                onViewEticket: (_) => _showEticketNotice(context),
                onWriteReview: (t) => _navigateToReview(context, t),
                onEditReview: (t) => _navigateToReview(context, t),
                onViewReview: (t) => _navigateToReview(context, t),
                onViewRefundStatus: (t) {
                  if (t.refundInfo != null) {
                    showDialog<void>(
                      context: context,
                      builder: (_) => RefundStatusDialog(
                        refundInfo: t.refundInfo!,
                        bookingCode: t.bookingCode,
                      ),
                    );
                  }
                },
                onViewDetails: (t) {
                  if (t.isItinerary && t.itineraryId != null) {
                    context.push('/traveler/itineraries/${t.itineraryId}');
                  } else {
                    _showBookingDetailsDialog(context, t);
                  }
                },
              );
            },
          ),
        ),
        // Pagination Controls at bottom
        _buildPaginationBar(context, state, cubit),
      ],
    );
  }

  Widget _buildPaginationBar(
    BuildContext context,
    TripHistoryState state,
    TripHistoryCubit cubit,
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
