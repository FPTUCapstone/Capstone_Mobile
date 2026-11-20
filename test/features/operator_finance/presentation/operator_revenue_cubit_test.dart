import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/repositories/operator_finance_repository.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_revenue_cubit.dart';

RevenueReport report({int page = 1, num net = 4500}) => RevenueReport(
  summary: RevenueSummary(
    grossRevenue: 10000,
    paymentsReceived: 10000,
    discountsGiven: 0,
    refundedAmount: 5000,
    netSales: 5000,
    platformCommission: 500,
    netAmount: net,
    totalBookings: 2,
    totalParticipants: 3,
    commissionRatePercent: 10,
  ),
  chartData: [
    RevenuePeriod(
      periodKey: '2026-11',
      periodLabel: '2026-11',
      grossRevenue: 10000,
      commission: 500,
      netAmount: net,
      refundedAmount: 5000,
      bookingsCount: 2,
    ),
  ],
  tourDetails: [
    TourRevenue(
      tourId: page,
      tourCode: 'TOUR-$page',
      tourName: 'Tour $page',
      bookingsCount: 2,
      participantsCount: 3,
      grossRevenue: 10000,
      refundedAmount: 5000,
      commission: 500,
      netAmount: net,
    ),
  ],
  totalToursCount: 20,
  page: page,
  pageSize: 10,
  totalPages: 2,
);

class RevenueRepository implements OperatorFinanceRepository {
  final queries = <RevenueQuery>[];
  int optionCalls = 0;
  Future<RevenueReport> Function(RevenueQuery) respond = (query) async =>
      report(page: query.page);
  Future<List<RevenueTourOption>> Function() options = () async => [];

  @override
  Future<RevenueReport> loadReport(RevenueQuery query) {
    queries.add(query);
    return respond(query);
  }

  @override
  Future<List<RevenueTourOption>> loadTourOptions() {
    optionCalls++;
    return options();
  }

  @override
  Future<SettlementHistory> loadSettlementHistory({
    int page = 1,
    int pageSize = 10,
  }) => throw UnimplementedError();
}

void main() {
  test('compact overview loads monthly report without tour options', () async {
    final repository = RevenueRepository();
    final cubit = OperatorRevenueCubit(repository, includeTourOptions: false);
    await cubit.ensureLoaded();
    await cubit.apply(
      RevenueQuery(
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 10, 31),
      ),
    );
    expect(repository.queries, hasLength(2));
    expect(repository.optionCalls, 0);
    expect(cubit.state.report?.summary.netAmount, 4500);
    await cubit.close();
  });
  test('initial month uses Vietnam calendar and loads only once', () async {
    final repository = RevenueRepository();
    final cubit = OperatorRevenueCubit(
      repository,
      now: () => DateTime.utc(2026, 12, 31, 18),
    );
    addTearDown(cubit.close);
    expect(cubit.state.query.startDate, DateTime(2027, 1, 1));
    expect(cubit.state.query.endDate, DateTime(2027, 1, 31));
    expect(cubit.previousMonthQuery().startDate, DateTime(2026, 12, 1));
    expect(cubit.previousMonthQuery().endDate, DateTime(2026, 12, 31));
    await cubit.ensureLoaded();
    await cubit.ensureLoaded();
    expect(repository.queries, hasLength(1));
    expect(repository.optionCalls, 1);
  });

  test(
    'invalid range makes no request and does not expose raw validation',
    () async {
      final repository = RevenueRepository();
      final cubit = OperatorRevenueCubit(repository);
      addTearDown(cubit.close);
      await cubit.apply(
        RevenueQuery(
          startDate: DateTime(2026, 12, 2),
          endDate: DateTime(2026, 12, 1),
        ),
      );
      expect(repository.queries, isEmpty);
      expect(cubit.state.error, isNotNull);
    },
  );

  test(
    'paging atomically replaces summary chart rows and page metadata',
    () async {
      final repository = RevenueRepository();
      final cubit = OperatorRevenueCubit(repository);
      addTearDown(cubit.close);
      await cubit.ensureLoaded();
      final token = cubit.state.scrollResetToken;
      repository.respond = (query) async =>
          report(page: query.page, net: -12000);
      await cubit.changePage(2);
      expect(cubit.state.query.page, 2);
      expect(cubit.state.report!.page, 2);
      expect(cubit.state.report!.summary.netAmount, -12000);
      expect(cubit.state.report!.chartData.single.netAmount, -12000);
      expect(cubit.state.report!.tourDetails.single.tourId, 2);
      expect(cubit.state.scrollResetToken, token);
    },
  );

  test(
    'failed next page preserves committed snapshot and retries that page',
    () async {
      final repository = RevenueRepository();
      final cubit = OperatorRevenueCubit(repository);
      addTearDown(cubit.close);
      await cubit.ensureLoaded();
      final snapshot = cubit.state.report;
      repository.respond = (_) async => throw const ServerFailure('SQL secret');
      await cubit.changePage(2);
      expect(cubit.state.report, same(snapshot));
      expect(cubit.state.query.page, 1);
      expect(cubit.state.error, isNot(contains('SQL')));
      repository.respond = (query) async => report(page: query.page);
      await cubit.retry();
      expect(repository.queries.last.page, 2);
      expect(cubit.state.query.page, 2);
    },
  );

  test(
    'failed filter keeps old query; apply success and refresh reset page and scroll',
    () async {
      final repository = RevenueRepository();
      final cubit = OperatorRevenueCubit(
        repository,
        now: () => DateTime.utc(2026, 11, 19),
      );
      addTearDown(cubit.close);
      await cubit.ensureLoaded();
      await cubit.changePage(2);
      final query = cubit.state.query;
      final next = query.copyWith(
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
      );
      repository.respond = (_) async => throw const NetworkFailure();
      await cubit.apply(next);
      expect(cubit.state.query, query);
      final token = cubit.state.scrollResetToken;
      repository.respond = (query) async => report(page: query.page);
      await cubit.retry();
      expect(cubit.state.query.page, 1);
      expect(cubit.state.query.startDate, DateTime(2026, 10, 1));
      expect(cubit.state.scrollResetToken, token + 1);
      await cubit.changePage(2);
      final refreshToken = cubit.state.scrollResetToken;
      await cubit.refresh();
      expect(cubit.state.query.page, 1);
      expect(cubit.state.query.startDate, DateTime(2026, 10, 1));
      expect(cubit.state.scrollResetToken, refreshToken + 1);
    },
  );

  test(
    'newer filter supersedes old response while duplicate request is ignored',
    () async {
      final repository = RevenueRepository();
      final first = Completer<RevenueReport>();
      final second = Completer<RevenueReport>();
      repository.respond = (_) =>
          repository.queries.length == 1 ? first.future : second.future;
      final cubit = OperatorRevenueCubit(
        repository,
        now: () => DateTime.utc(2026, 11, 19),
      );
      addTearDown(cubit.close);
      final request = cubit.ensureLoaded();
      final newer = cubit.state.query.copyWith(tourId: 7);
      final newerRequest = cubit.apply(newer);
      await cubit.apply(newer);
      expect(repository.queries, hasLength(2));
      second.complete(report(net: 9000));
      await newerRequest;
      first.complete(report(net: 4500));
      await request;
      expect(cubit.state.query.tourId, 7);
      expect(cubit.state.report!.summary.netAmount, 9000);
    },
  );

  test(
    'option failures do not block all-tour report and can retry separately',
    () async {
      final repository = RevenueRepository()
        ..options = () async => throw const ServerFailure();
      final cubit = OperatorRevenueCubit(repository);
      addTearDown(cubit.close);
      await cubit.ensureLoaded();
      expect(cubit.state.report, isNotNull);
      expect(cubit.state.optionsError, isNotNull);
      repository.options = () async => [
        const RevenueTourOption(
          id: 3,
          code: 'TOUR-3',
          title: 'Historical tour',
          isActive: false,
        ),
      ];
      await cubit.loadOptions();
      expect(cubit.state.options.single.isActive, isFalse);
      expect(cubit.state.optionsError, isNull);
      expect(repository.queries, hasLength(1));
    },
  );

  test(
    'permission failure is explicit and clears previously visible financial data',
    () async {
      final repository = RevenueRepository();
      final cubit = OperatorRevenueCubit(repository);
      addTearDown(cubit.close);
      await cubit.ensureLoaded();
      repository.respond = (_) async =>
          throw const PermissionFailure('server text');
      await cubit.refresh();
      expect(cubit.state.forbidden, isTrue);
      expect(cubit.state.report, isNull);
      expect(cubit.state.error, isNot(contains('server text')));
    },
  );

  test(
    'options access loss clears cached data and invalidates a pending report',
    () async {
      final repository = RevenueRepository()
        ..options = () async => [
          const RevenueTourOption(
            id: 3,
            code: 'TOUR-3',
            title: 'Private tour',
            isActive: true,
          ),
        ];
      final cubit = OperatorRevenueCubit(repository);
      addTearDown(cubit.close);
      await cubit.ensureLoaded();
      expect(cubit.state.report, isNotNull);
      expect(cubit.state.options, hasLength(1));
      final pending = Completer<RevenueReport>();
      repository.respond = (_) => pending.future;
      final reportRequest = cubit.refresh();
      repository.options = () async =>
          throw const PermissionFailure('private denial');
      await cubit.loadOptions();
      expect(cubit.state.forbidden, isTrue);
      expect(cubit.state.report, isNull);
      expect(cubit.state.options, isEmpty);
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.error, isNot(contains('private denial')));
      pending.complete(report(net: 999999));
      await reportRequest;
      expect(cubit.state.report, isNull);
      expect(cubit.state.forbidden, isTrue);
      repository.respond = (_) async => report(net: 4500);
      await cubit.refresh();
      expect(cubit.state.forbidden, isFalse);
      expect(cubit.state.report!.summary.netAmount, 4500);
    },
  );

  test('late responses after disposal do not emit', () async {
    final repository = RevenueRepository();
    final pending = Completer<RevenueReport>();
    repository.respond = (_) => pending.future;
    final cubit = OperatorRevenueCubit(repository);
    final request = cubit.ensureLoaded();
    await cubit.close();
    pending.complete(report());
    await request;
    expect(cubit.isClosed, isTrue);
  });
}
