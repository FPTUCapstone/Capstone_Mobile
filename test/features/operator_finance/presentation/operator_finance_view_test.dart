import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_finance/data/repositories/demo_operator_finance_repository.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/repositories/operator_finance_repository.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_revenue_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_settlement_history_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/operator_finance_view.dart';

class _OverviewRepository implements OperatorFinanceRepository {
  final queries = <RevenueQuery>[];
  int historyCalls = 0;
  int optionsCalls = 0;
  bool failRevenue = false;
  bool failHistory = false;
  final _demo = const DemoOperatorFinanceRepository();
  @override
  Future<RevenueReport> loadReport(RevenueQuery query) {
    queries.add(query);
    if (failRevenue) throw const ServerFailure('private database details');
    return _demo.loadReport(query);
  }

  @override
  Future<List<RevenueTourOption>> loadTourOptions() async {
    optionsCalls++;
    return [];
  }

  @override
  Future<SettlementHistory> loadSettlementHistory({
    int page = 1,
    int pageSize = 10,
  }) async {
    historyCalls++;
    if (failHistory) throw const ServerFailure('private database details');
    return SettlementHistory(
      pageNumber: page,
      pageSize: pageSize,
      totalCount: 5,
      items: List.generate(
        5,
        (index) => PayoutSettlement(
          settlementId: index + 1,
          batchId: 1,
          bookingId: 100 + index,
          tourOperatorUserId: 1,
          runDate: DateTime(2026, 11, 19 - index),
          kind: 'Advance',
          payoutAmount: 7000,
          status: 'Settled',
          transferReference: null,
        ),
      ),
    );
  }
}

void main() {
  tearDown(() => serviceLocator.reset());

  testWidgets('explicit demo never uses the injected live repositories', (
    tester,
  ) async {
    serviceLocator.registerFactoryParam<OperatorRevenueCubit, bool, void>((
      demo,
      _,
    ) {
      expect(demo, isTrue);
      return OperatorRevenueCubit(
        const DemoOperatorFinanceRepository(),
        includeTourOptions: false,
      );
    });
    serviceLocator
        .registerFactoryParam<OperatorSettlementHistoryCubit, bool, void>((
          demo,
          _,
        ) {
          expect(demo, isTrue);
          return OperatorSettlementHistoryCubit(
            const DemoOperatorFinanceRepository(),
          );
        });
    final repository = _OverviewRepository();
    final revenue = OperatorRevenueCubit(repository, includeTourOptions: false);
    final history = OperatorSettlementHistoryCubit(repository);
    addTearDown(revenue.close);
    addTearDown(history.close);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OperatorFinanceView(
            isDemoMode: true,
            revenueCubit: revenue,
            settlementCubit: history,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('DỮ LIỆU DEMO'), findsOneWidget);
    expect(repository.queries, isEmpty);
    expect(repository.historyCalls, 0);
    expect(repository.optionsCalls, 0);
  });

  testWidgets(
    'a recent-history failure does not hide a valid monthly summary',
    (tester) async {
      final repository = _OverviewRepository()..failHistory = true;
      final revenue = OperatorRevenueCubit(
        repository,
        includeTourOptions: false,
      );
      final history = OperatorSettlementHistoryCubit(repository);
      addTearDown(revenue.close);
      addTearDown(history.close);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperatorFinanceView(
              revenueCubit: revenue,
              settlementCubit: history,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4.500 VNĐ'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Thử lại'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('private database'), findsNothing);
      repository.failHistory = false;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(repository.queries, hasLength(1));
      expect(repository.historyCalls, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'single overview shows BE summary and only three recent settlements',
    (tester) async {
      final repository = _OverviewRepository();
      final revenue = OperatorRevenueCubit(
        repository,
        now: () => DateTime.utc(2026, 11, 19),
      );
      final history = OperatorSettlementHistoryCubit(repository);
      addTearDown(revenue.close);
      addTearDown(history.close);
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OperatorFinanceView(
              revenueCubit: revenue,
              settlementCubit: history,
              onOpenHistory: () => opened++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tổng quan tài chính'), findsOneWidget);
      expect(find.text('Tháng 11/2026'), findsOneWidget);
      expect(find.text('4.500 VNĐ'), findsOneWidget);
      expect(find.text('Giá trị tour'), findsOneWidget);
      expect(find.text('Đã hoàn khách'), findsOneWidget);
      expect(find.text('1 đơn · 1 khách'), findsOneWidget);
      expect(find.byKey(const Key('finance-section-revenue')), findsNothing);
      expect(find.text('Bộ lọc'), findsNothing);
      expect(find.text('Biến động theo kỳ'), findsNothing);
      expect(find.text('Doanh thu theo tour'), findsNothing);
      expect(find.textContaining('báo cáo chi tiết'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Đơn #102'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Đơn #103'), findsNothing);
      expect(find.text('Đơn #104'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Xem tất cả'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Xem tất cả'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Xem tất cả'));
      expect(opened, 1);
      expect(history.state.history!.pageNumber, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'month changes only report and activation refreshes both summaries',
    (tester) async {
      final repository = _OverviewRepository();
      final revenue = OperatorRevenueCubit(
        repository,
        now: () => DateTime.utc(2026, 11, 19),
      );
      final history = OperatorSettlementHistoryCubit(repository);
      addTearDown(revenue.close);
      addTearDown(history.close);
      Future<void> mount(bool active) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OperatorFinanceView(
                isActive: active,
                revenueCubit: revenue,
                settlementCubit: history,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount(false);
      expect(repository.queries, isEmpty);
      expect(repository.historyCalls, 0);
      await mount(true);
      expect(repository.historyCalls, 1);
      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();
      expect(find.text('Tháng 10/2026'), findsOneWidget);
      expect(repository.queries.last.startDate, DateTime(2026, 10));
      expect(repository.queries.last.endDate, DateTime(2026, 10, 31));
      expect(repository.queries.last.granularity, 'monthly');
      expect(repository.queries.last.tourId, isNull);
      expect(repository.historyCalls, 1);
      await mount(false);
      await mount(true);
      expect(repository.historyCalls, 2);
      expect(find.text('Tháng 10/2026'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repository.historyCalls, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overview remains readable at 320dp with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _OverviewRepository();
    final revenue = OperatorRevenueCubit(repository);
    final history = OperatorSettlementHistoryCubit(repository);
    addTearDown(revenue.close);
    addTearDown(history.close);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: OperatorFinanceView(
              revenueCubit: revenue,
              settlementCubit: history,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tổng quan tài chính'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Quyết toán gần đây'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
