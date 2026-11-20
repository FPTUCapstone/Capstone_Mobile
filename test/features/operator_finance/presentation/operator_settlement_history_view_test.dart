import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/repositories/operator_finance_repository.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_settlement_history_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/operator_settlement_history_view.dart';

class HistoryViewRepository implements OperatorFinanceRepository {
  @override
  Future<SettlementHistory> loadSettlementHistory({
    int page = 1,
    int pageSize = 10,
  }) async => SettlementHistory(
    pageNumber: page,
    pageSize: pageSize,
    totalCount: 1,
    items: [
      PayoutSettlement(
        settlementId: 1,
        batchId: null,
        bookingId: 7,
        tourOperatorUserId: 3,
        runDate: DateTime(2026, 11, 19),
        kind: 'Cancellation',
        payoutAmount: 4500,
        status: 'Resolved',
        transferReference: null,
      ),
    ],
  );
  @override
  Future<RevenueReport> loadReport(RevenueQuery query) =>
      throw UnimplementedError();
  @override
  Future<List<RevenueTourOption>> loadTourOptions() async => [];
}

void main() {
  testWidgets(
    'Cancellation and Resolved are read-only and null reference stays truthful',
    (tester) async {
      final cubit = OperatorSettlementHistoryCubit(HistoryViewRepository());
      addTearDown(cubit.close);
      await cubit.ensureLoaded();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OperatorSettlementHistoryView(cubit: cubit)),
        ),
      );
      expect(find.text('Quyết toán hủy tour'), findsOneWidget);
      expect(find.text('Đã xử lý'), findsOneWidget);
      expect(find.text('Đã quyết toán'), findsNothing);
      expect(find.text('Đơn #7'), findsOneWidget);
      await tester.tap(find.text('Đơn #7'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có mã giao dịch'), findsOneWidget);
      expect(find.text('Rút tiền'), findsNothing);
      expect(find.text('Xác nhận'), findsNothing);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết quyết toán'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
