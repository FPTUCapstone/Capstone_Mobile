import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_settlement_history_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/settlement_history_card.dart';

class OperatorSettlementHistoryView extends StatefulWidget {
  const OperatorSettlementHistoryView({
    required this.cubit,
    this.showTitle = true,
    super.key,
  });
  final OperatorSettlementHistoryCubit cubit;
  final bool showTitle;
  @override
  State<OperatorSettlementHistoryView> createState() =>
      _OperatorSettlementHistoryViewState();
}

class _OperatorSettlementHistoryViewState
    extends State<OperatorSettlementHistoryView> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<OperatorSettlementHistoryCubit, OperatorSettlementHistoryState>(
    bloc: widget.cubit,
    listenWhen: (oldState, state) =>
        oldState.scrollResetToken != state.scrollResetToken,
    listener: (_, _) => WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    }),
    builder: (context, state) {
      final history = state.history;
      final pages = history == null || history.totalCount == 0
          ? 0
          : (history.totalCount / history.pageSize).ceil();
      return RefreshIndicator(
        onRefresh: widget.cubit.refresh,
        child: ListView(
          key: const PageStorageKey('operator-settlement-history-scroll'),
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (widget.showTitle)
              Text(
                'Lịch sử quyết toán',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            const Text(
              'Theo ngày chạy đợt chuyển tiền, độc lập với kỳ báo cáo doanh thu.',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: state.loading ? null : widget.cubit.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Làm mới lịch sử'),
              ),
            ),
            if (state.error != null) ...[
              Text(state.error!, style: const TextStyle(color: Colors.red)),
              if (!state.forbidden)
                TextButton(
                  onPressed: state.loading ? null : widget.cubit.retry,
                  child: const Text('Thử lại'),
                ),
            ],
            if (state.loading && history != null)
              const LinearProgressIndicator(
                semanticsLabel: 'Đang tải lịch sử mới',
              ),
            if (history == null && (state.loading || state.error == null))
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Đang tải lịch sử',
                  ),
                ),
              )
            else if (history != null && !state.forbidden) ...[
              if (history.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Chưa có lịch sử quyết toán.'),
                ),
              for (final settlement in history.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SettlementHistoryCard(
                    key: ValueKey(
                      settlement.settlementId ??
                          '${settlement.bookingId}-${settlement.kind}',
                    ),
                    settlement: settlement,
                  ),
                ),
              if (pages > 0)
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: state.loading || history.pageNumber <= 1
                          ? null
                          : () =>
                                widget.cubit.changePage(history.pageNumber - 1),
                      child: const Text('Trang trước'),
                    ),
                    Text('Trang ${history.pageNumber}/$pages'),
                    TextButton(
                      onPressed: state.loading || history.pageNumber >= pages
                          ? null
                          : () =>
                                widget.cubit.changePage(history.pageNumber + 1),
                      child: const Text('Trang sau'),
                    ),
                  ],
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      );
    },
  );
}
