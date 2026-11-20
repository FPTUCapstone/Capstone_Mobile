import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_revenue_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_settlement_history_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/revenue_financial_details.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/settlement_detail_sheet.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

/// Compact mobile companion; all financial figures are provided by UC44.
class OperatorFinanceOverview extends StatefulWidget {
  const OperatorFinanceOverview({
    required this.revenueCubit,
    required this.settlementCubit,
    required this.onRefresh,
    required this.onOpenHistory,
    this.isDemoMode = false,
    super.key,
  });

  final OperatorRevenueCubit revenueCubit;
  final OperatorSettlementHistoryCubit settlementCubit;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenHistory;
  final bool isDemoMode;

  @override
  State<OperatorFinanceOverview> createState() =>
      _OperatorFinanceOverviewState();
}

class _OperatorFinanceOverviewState extends State<OperatorFinanceOverview> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _moveMonth(int delta) {
    final current = widget.revenueCubit.state.query.startDate;
    final month = DateTime(current.year, current.month + delta);
    widget.revenueCubit.apply(
      RevenueQuery(
        startDate: month,
        endDate: DateTime(month.year, month.month + 1, 0),
        granularity: 'monthly',
        page: 1,
        pageSize: 10,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<OperatorRevenueCubit, OperatorRevenueState>(
    bloc: widget.revenueCubit,
    listenWhen: (oldState, state) =>
        oldState.scrollResetToken != state.scrollResetToken,
    listener: (_, _) => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    }),
    builder: (context, revenue) =>
        BlocBuilder<
          OperatorSettlementHistoryCubit,
          OperatorSettlementHistoryState
        >(
          bloc: widget.settlementCubit,
          builder: (context, history) {
            final report = revenue.report;
            final month = revenue.query.startDate;
            return RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: ListView(
                key: const PageStorageKey('operator-finance-overview-scroll'),
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (widget.isDemoMode)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'DỮ LIỆU DEMO — Chỉ để minh họa, không phải số liệu tài chính thật.',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tổng quan tài chính',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Làm mới tài chính',
                        onPressed: revenue.loading || history.loading
                            ? null
                            : widget.onRefresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Tháng trước',
                        onPressed: revenue.loading
                            ? null
                            : () => _moveMonth(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          'Tháng ${month.month}/${month.year}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tháng sau',
                        onPressed: revenue.loading ? null : () => _moveMonth(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (revenue.error != null)
                    _error(
                      revenue.error!,
                      revenue.forbidden ? null : widget.revenueCubit.retry,
                    ),
                  if (revenue.loading && report != null)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Đang tải tháng mới',
                    ),
                  if (report == null && revenue.error == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(
                          semanticsLabel: 'Đang tải tài chính',
                        ),
                      ),
                    ),
                  if (report != null && !revenue.forbidden) ...[
                    _summary(context, report.summary),
                    if (report.summary.totalBookings == 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Chưa có dữ liệu trong tháng này.'),
                      ),
                  ],
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Quyết toán gần đây',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      TextButton(
                        onPressed: widget.onOpenHistory,
                        child: const Text('Xem tất cả'),
                      ),
                    ],
                  ),
                  const Text(
                    'Các đợt gần nhất, không giới hạn theo tháng đang chọn.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  if (history.error != null)
                    _error(
                      history.error!,
                      history.forbidden ? null : widget.settlementCubit.retry,
                    ),
                  if (history.loading)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Đang tải quyết toán gần đây',
                    ),
                  if (history.history != null && !history.forbidden) ...[
                    if (history.history!.items.isEmpty)
                      const Text('Chưa có lịch sử quyết toán.'),
                    for (final settlement in history.history!.items.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _recentSettlement(context, settlement),
                      ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
  );

  Widget _recentSettlement(
    BuildContext context,
    PayoutSettlement settlement,
  ) => AppCard(
    key: ValueKey(
      'recent-settlement-${settlement.settlementId ?? settlement.bookingId}',
    ),
    padding: const EdgeInsets.all(12),
    onTap: () => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => SettlementDetailSheet(settlement: settlement),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final date = settlement.runDate == null
            ? 'Chưa có ngày chạy'
            : financeDay(settlement.runDate!);
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$date · ${settlementKindLabel(settlement.kind)}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              'Đơn #${settlement.bookingId}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        );
        final amount = Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatVnd(settlement.payoutAmount),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              settlementStatusLabel(settlement.status),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                color: settlement.status == 'Settled'
                    ? AppColors.success
                    : AppColors.muted,
              ),
            ),
          ],
        );
        if (constraints.maxWidth < 270 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [details, const SizedBox(height: 8), amount],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: details),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: amount),
          ],
        );
      },
    ),
  );

  Widget _error(String message, VoidCallback? retry) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: AppColors.error)),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('Thử lại')),
      ],
    ),
  );

  Widget _summary(BuildContext context, RevenueSummary summary) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppCard(
        backgroundColor: AppColors.primary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thực nhận', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              formatVnd(summary.netAmount),
              key: const Key('finance-overview-net'),
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đã quyết toán, trừ hoàn trả đã xác nhận.',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final narrow =
              constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(14) > 20;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in [
                ('Giá trị tour', summary.grossRevenue),
                ('Đã hoàn khách', summary.refundedAmount),
              ])
                SizedBox(
                  width: narrow
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 12) / 2,
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatVnd(item.$2),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      Text(
        '${summary.totalBookings} đơn · ${summary.totalParticipants} khách',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 4),
      const Text(
        'Theo tháng khách thanh toán trên TripMate.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    ],
  );
}
