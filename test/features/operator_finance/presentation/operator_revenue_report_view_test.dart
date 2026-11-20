import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/repositories/operator_finance_repository.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_revenue_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/operator_revenue_report_view.dart';

class ViewRepository implements OperatorFinanceRepository {
  @override
  Future<RevenueReport> loadReport(RevenueQuery query) async => RevenueReport(
    summary: RevenueSummary(
      grossRevenue: 10000,
      paymentsReceived: 10000,
      discountsGiven: 0,
      refundedAmount: 5000,
      netSales: 5000,
      platformCommission: 500,
      netAmount: 4500,
      totalBookings: 1,
      totalParticipants: 2,
      commissionRatePercent: 10,
    ),
    chartData: [],
    tourDetails: [
      TourRevenue(
        tourId: 1,
        tourCode: 'TOUR-1',
        tourName:
            'Tour Đà Nẵng và Hội An có tiêu đề rất dài để kiểm tra màn hình nhỏ',
        bookingsCount: 1,
        participantsCount: 2,
        grossRevenue: 10000,
        refundedAmount: 5000,
        commission: 500,
        netAmount: 4500,
      ),
    ],
    totalToursCount: 1,
    page: query.page,
    pageSize: 10,
    totalPages: 1,
  );
  @override
  Future<List<RevenueTourOption>> loadTourOptions() async => [];
  @override
  Future<SettlementHistory> loadSettlementHistory({
    int page = 1,
    int pageSize = 10,
  }) => throw UnimplementedError();
}

void main() {
  testWidgets(
    'renders server net and details safely on small screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cubit = OperatorRevenueCubit(
        ViewRepository(),
        now: () => DateTime.utc(2026, 11, 19),
      );
      addTearDown(cubit.close);
      await cubit.ensureLoaded();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(body: OperatorRevenueReportView(cubit: cubit)),
          ),
        ),
      );
      expect(find.byKey(const Key('revenue-net-amount')), findsOneWidget);
      expect(find.text('4.500 VNĐ'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Xem chi tiết số liệu'),
        250,
        scrollable: find
            .descendant(
              of: find.byKey(
                const PageStorageKey('operator-revenue-report-scroll'),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Xem chi tiết số liệu'));
      await tester.pumpAndSettle();
      expect(find.text('Thực nhận đã quyết toán'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('canceling filter leaves committed query unchanged', (
    tester,
  ) async {
    final cubit = OperatorRevenueCubit(
      ViewRepository(),
      now: () => DateTime.utc(2026, 11, 19),
    );
    addTearDown(cubit.close);
    await cubit.ensureLoaded();
    final query = cubit.state.query;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OperatorRevenueReportView(cubit: cubit)),
      ),
    );
    await tester.tap(find.text('Bộ lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tháng trước'));
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(cubit.state.query, query);
  });
}
