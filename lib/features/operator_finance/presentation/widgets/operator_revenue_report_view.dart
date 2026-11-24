import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_revenue_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/revenue_filter_sheet.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/revenue_financial_details.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/revenue_period_chart.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/revenue_summary_cards.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/tour_revenue_list.dart';

class OperatorRevenueReportView extends StatefulWidget {
  const OperatorRevenueReportView({required this.cubit, super.key});
  final OperatorRevenueCubit cubit;
  @override
  State<OperatorRevenueReportView> createState() =>
      _OperatorRevenueReportViewState();
}

class _OperatorRevenueReportViewState extends State<OperatorRevenueReportView> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _filters() async {
    unawaited(widget.cubit.loadOptions());
    final query = await showModalBottomSheet<RevenueQuery>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => RevenueFilterSheet(cubit: widget.cubit),
    );
    if (query != null && mounted) await widget.cubit.apply(query);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<OperatorRevenueCubit, OperatorRevenueState>(
    bloc: widget.cubit,
    listenWhen: (oldState, state) =>
        oldState.scrollResetToken != state.scrollResetToken,
    listener: (_, _) => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    }),
    builder: (context, state) {
      final report = state.report;
      final tour = state.options
          .where((tour) => tour.id == state.query.tourId)
          .firstOrNull;
      return RefreshIndicator(
        onRefresh: widget.cubit.refresh,
        child: ListView(
          key: const PageStorageKey('operator-revenue-report-scroll'),
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Báo cáo doanh thu',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${financeDay(state.query.startDate)} – ${financeDay(state.query.endDate)} · Giờ Việt Nam',
            ),
            Text(
              state.query.tourId == null
                  ? 'Tất cả tour'
                  : tour?.title ?? 'Tour #${state.query.tourId}',
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: state.loading ? null : _filters,
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Bộ lọc'),
                ),
                TextButton.icon(
                  onPressed: state.loading ? null : widget.cubit.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm mới'),
                ),
              ],
            ),
            if (state.error != null) ...[
              Text(state.error!, style: const TextStyle(color: Colors.red)),
              if (!state.forbidden)
                TextButton(
                  onPressed: state.loading ? null : widget.cubit.retry,
                  child: const Text('Thử lại'),
                ),
            ],
            if (state.loading && report != null)
              const LinearProgressIndicator(
                semanticsLabel: 'Đang tải báo cáo mới',
              ),
            if (report == null && (state.loading || state.error == null))
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Đang tải báo cáo',
                  ),
                ),
              )
            else if (report != null && !state.forbidden) ...[
              if (report.summary.totalBookings == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Không có dữ liệu doanh thu trong kỳ đã chọn.'),
                ),
              RevenueSummaryCards(summary: report.summary),
              const SizedBox(height: 16),
              RevenueFinancialDetails(summary: report.summary),
              const SizedBox(height: 16),
              RevenuePeriodChart(periods: report.chartData),
              const SizedBox(height: 16),
              TourRevenueList(
                report: report,
                loading: state.loading,
                onPage: widget.cubit.changePage,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      );
    },
  );
}
