import 'package:flutter/material.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/revenue_financial_details.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';
import 'package:trip_mate_mobile/shared/widgets/app_card.dart';

class TourRevenueList extends StatelessWidget {
  const TourRevenueList({
    required this.report,
    required this.loading,
    required this.onPage,
    super.key,
  });
  final RevenueReport report;
  final bool loading;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Doanh thu theo tour',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      if (report.tourDetails.isEmpty)
        const Text('Chưa có tour trong kết quả này.'),
      for (final tour in report.tourDetails)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            key: ValueKey('tour-revenue-${tour.tourId}'),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              useSafeArea: true,
              isScrollControlled: true,
              builder: (context) => SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tour.tourName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    FinanceValueLine(label: 'Mã tour', value: tour.tourCode),
                    FinanceValueLine(
                      label: 'Số đơn',
                      value: '${tour.bookingsCount}',
                    ),
                    FinanceValueLine(
                      label: 'Số khách',
                      value: '${tour.participantsCount}',
                    ),
                    FinanceValueLine(
                      label: 'Giá trị đặt tour',
                      value: formatVnd(tour.grossRevenue),
                    ),
                    FinanceValueLine(
                      label: 'Tiền hoàn',
                      value: formatVnd(tour.refundedAmount),
                    ),
                    FinanceValueLine(
                      label: 'Hoa hồng',
                      value: formatVnd(tour.commission),
                    ),
                    FinanceValueLine(
                      label: 'Thực nhận',
                      value: formatVnd(tour.netAmount),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tour.tourName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(tour.tourCode),
                Text('${tour.bookingsCount} đơn'),
                Text('Giá trị đặt tour: ${formatVnd(tour.grossRevenue)}'),
                Text('Thực nhận: ${formatVnd(tour.netAmount)}'),
                const SizedBox(height: 4),
                const Text(
                  'Xem chi tiết',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
              ],
            ),
          ),
        ),
      if (report.totalPages > 0)
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            TextButton(
              onPressed: loading || report.page <= 1
                  ? null
                  : () => onPage(report.page - 1),
              child: const Text('Trang trước'),
            ),
            Text('Trang ${report.page}/${report.totalPages}'),
            TextButton(
              onPressed: loading || report.page >= report.totalPages
                  ? null
                  : () => onPage(report.page + 1),
              child: const Text('Trang sau'),
            ),
          ],
        ),
    ],
  );
}
