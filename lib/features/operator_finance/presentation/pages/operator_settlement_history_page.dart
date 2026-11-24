import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_settlement_history_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/operator_settlement_history_view.dart';

class OperatorSettlementHistoryPage extends StatelessWidget {
  const OperatorSettlementHistoryPage({this.isDemoMode = false, super.key});
  final bool isDemoMode;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Lịch sử quyết toán'),
      leading: IconButton(
        tooltip: 'Quay lại',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(
              isDemoMode
                  ? '${AppRoutes.operator}?demo=true'
                  : AppRoutes.operator,
            );
          }
        },
      ),
    ),
    body: Column(
      children: [
        if (isDemoMode)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'DỮ LIỆU DEMO — Chỉ để minh họa, không phải giao dịch thật.',
            ),
          ),
        Expanded(
          child: OperatorSettlementHistoryView(
            cubit: context.read<OperatorSettlementHistoryCubit>(),
            showTitle: false,
          ),
        ),
      ],
    ),
  );
}
