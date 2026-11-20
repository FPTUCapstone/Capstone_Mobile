import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/revenue_financial_details.dart';
import 'package:trip_mate_mobile/shared/formatters/visit_price_format.dart';

String settlementKindLabel(String kind) => switch (kind) {
  'Advance' => 'Tạm ứng',
  'Final' => 'Quyết toán cuối',
  'Cancellation' => 'Quyết toán hủy tour',
  _ => 'Chưa hỗ trợ hiển thị',
};

String settlementStatusLabel(String status) => switch (status) {
  'Scheduled' => 'Chờ chuyển',
  'Processing' => 'Đang xử lý',
  'Settled' => 'Đã quyết toán',
  'SettlementFailed' => 'Chuyển tiền thất bại',
  'Resolved' => 'Đã xử lý',
  'Awaiting Window' => 'Chờ đủ thời gian',
  _ => 'Chưa hỗ trợ hiển thị',
};

class SettlementDetailSheet extends StatelessWidget {
  const SettlementDetailSheet({required this.settlement, super.key});
  final PayoutSettlement settlement;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Chi tiết quyết toán',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        FinanceValueLine(
          label: 'ID quyết toán',
          value: settlement.settlementId?.toString() ?? 'Chưa có',
        ),
        FinanceValueLine(
          label: 'ID đợt chuyển',
          value: settlement.batchId?.toString() ?? 'Chưa có',
        ),
        FinanceValueLine(
          label: 'Đơn đặt tour',
          value: '#${settlement.bookingId}',
        ),
        FinanceValueLine(
          label: 'Ngày chạy',
          value: settlement.runDate == null
              ? 'Chưa có'
              : financeDay(settlement.runDate!),
        ),
        FinanceValueLine(
          label: 'Loại',
          value: settlementKindLabel(settlement.kind),
        ),
        FinanceValueLine(
          label: 'Số tiền',
          value: formatVnd(settlement.payoutAmount),
        ),
        FinanceValueLine(
          label: 'Trạng thái',
          value: settlementStatusLabel(settlement.status),
        ),
        FinanceValueLine(
          label: 'Mã giao dịch',
          value: settlement.transferReference ?? 'Chưa có mã giao dịch',
        ),
        if (settlement.status == 'Resolved')
          const Text(
            'Đợt đã được xử lý; trạng thái này không xác nhận rằng tiền đã chuyển thành công.',
          ),
        if (settlement.transferReference case final String reference)
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: reference));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép mã giao dịch')),
                );
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Sao chép mã giao dịch'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}
