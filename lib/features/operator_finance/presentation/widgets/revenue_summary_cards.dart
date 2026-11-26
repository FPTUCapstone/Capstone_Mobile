import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/app/theme/app_colors.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

class RevenueSummaryCards extends StatelessWidget {
  const RevenueSummaryCards({required this.summary, super.key});
  final RevenueSummary summary;

  @override
  Widget build(BuildContext context) => Column(
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
              key: const Key('revenue-net-amount'),
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Khoản đã quyết toán trừ hoàn trả đã xác nhận, của các đơn thanh toán trong kỳ.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final narrow =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(14) > 20;
          final items = <(String, String)>[
            ('Giá trị đặt tour', formatVnd(summary.grossRevenue)),
            ('Hoa hồng nền tảng', formatVnd(summary.platformCommission)),
            ('Tiền hoàn', formatVnd(summary.refundedAmount)),
            ('Số đơn', '${summary.totalBookings}'),
          ];
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final item in items)
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
                          item.$2,
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
    ],
  );
}
