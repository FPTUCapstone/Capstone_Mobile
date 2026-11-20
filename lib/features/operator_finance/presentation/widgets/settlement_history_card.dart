import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/revenue_financial_details.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/settlement_detail_sheet.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

class SettlementHistoryCard extends StatelessWidget {
  const SettlementHistoryCard({required this.settlement, super.key});
  final PayoutSettlement settlement;
  @override
  Widget build(BuildContext context) => AppCard(
    onTap: () => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => SettlementDetailSheet(settlement: settlement),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Đơn #${settlement.bookingId}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(settlementKindLabel(settlement.kind)),
        Text(
          settlement.runDate == null
              ? 'Chưa có ngày chạy'
              : financeDay(settlement.runDate!),
        ),
        Text(
          formatVnd(settlement.payoutAmount),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(settlementStatusLabel(settlement.status)),
        const SizedBox(height: 4),
        const Text(
          'Xem chi tiết',
          style: TextStyle(decoration: TextDecoration.underline),
        ),
      ],
    ),
  );
}
