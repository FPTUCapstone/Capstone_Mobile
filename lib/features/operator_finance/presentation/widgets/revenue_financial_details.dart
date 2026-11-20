import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

String financeDay(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class FinanceValueLine extends StatelessWidget {
  const FinanceValueLine({required this.label, required this.value, super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class RevenueFinancialDetails extends StatelessWidget {
  const RevenueFinancialDetails({required this.summary, super.key});
  final RevenueSummary summary;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Material(
      type: MaterialType.transparency,
      child: ExpansionTile(
        key: const PageStorageKey('revenue-financial-details-expansion'),
        tilePadding: EdgeInsets.zero,
        title: const Text('Xem chi tiết số liệu'),
        children: [
          for (final item in <(String, num)>[
            ('Giá trị đặt tour trước giảm giá', summary.grossRevenue),
            ('Giảm giá', summary.discountsGiven),
            ('Tiền đã thu', summary.paymentsReceived),
            ('Tiền hoàn cho khách', summary.refundedAmount),
            ('Doanh số sau hoàn', summary.netSales),
            ('Hoa hồng nền tảng', summary.platformCommission),
            ('Thực nhận đã quyết toán', summary.netAmount),
          ])
            FinanceValueLine(label: item.$1, value: formatVnd(item.$2)),
          FinanceValueLine(label: 'Số đơn', value: '${summary.totalBookings}'),
          FinanceValueLine(
            label: 'Số khách',
            value: '${summary.totalParticipants}',
          ),
          FinanceValueLine(
            label: 'Tỷ lệ hoa hồng tổng hợp',
            value: '${summary.commissionRatePercent}%',
          ),
          const Text(
            'Thực nhận theo các khoản chuyển tiền và hoàn trả đã xác nhận; không phải doanh số trừ hoa hồng.',
          ),
        ],
      ),
    ),
  );
}
