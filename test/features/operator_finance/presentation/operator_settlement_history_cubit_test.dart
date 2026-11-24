import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/repositories/operator_finance_repository.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_settlement_history_cubit.dart';

SettlementHistory history(int page) => SettlementHistory(
  pageNumber: page,
  pageSize: 10,
  totalCount: 20,
  items: [
    PayoutSettlement(
      settlementId: page,
      batchId: null,
      bookingId: page,
      tourOperatorUserId: 7,
      runDate: DateTime(2026, 11, 19),
      kind: 'Cancellation',
      payoutAmount: 4500,
      status: 'Settled',
      transferReference: null,
    ),
  ],
);

class HistoryRepository implements OperatorFinanceRepository {
  final pages = <int>[];
  Future<SettlementHistory> Function(int) respond = (page) async =>
      history(page);
  @override
  Future<SettlementHistory> loadSettlementHistory({
    int page = 1,
    int pageSize = 10,
  }) {
    expect(pageSize, 10);
    pages.add(page);
    return respond(page);
  }

  @override
  Future<RevenueReport> loadReport(RevenueQuery query) =>
      throw UnimplementedError();
  @override
  Future<List<RevenueTourOption>> loadTourOptions() =>
      throw UnimplementedError();
}

void main() {
  test(
    'lazy initial request once, paging independent, refresh resets page and scroll',
    () async {
      final repo = HistoryRepository();
      final cubit = OperatorSettlementHistoryCubit(repo);
      addTearDown(cubit.close);
      expect(repo.pages, isEmpty);
      await cubit.ensureLoaded();
      await cubit.ensureLoaded();
      expect(repo.pages, [1]);
      final token = cubit.state.scrollResetToken;
      await cubit.changePage(2);
      expect(cubit.state.history!.pageNumber, 2);
      expect(cubit.state.scrollResetToken, token);
      await cubit.refresh();
      expect(repo.pages, [1, 2, 1]);
      expect(cubit.state.scrollResetToken, token + 1);
    },
  );

  test(
    'page failure retains previous rows and retry requests pending page',
    () async {
      final repo = HistoryRepository();
      final cubit = OperatorSettlementHistoryCubit(repo);
      addTearDown(cubit.close);
      await cubit.ensureLoaded();
      final snapshot = cubit.state.history;
      repo.respond = (_) async =>
          throw const ServerFailure('private exception');
      await cubit.changePage(2);
      expect(cubit.state.history, same(snapshot));
      expect(cubit.state.error, isNot(contains('private')));
      repo.respond = (page) async => history(page);
      await cubit.retry();
      expect(repo.pages, [1, 2, 2]);
      expect(cubit.state.history!.pageNumber, 2);
    },
  );

  test(
    'refresh supersedes in-flight page; duplicate pages are guarded',
    () async {
      final repo = HistoryRepository();
      final cubit = OperatorSettlementHistoryCubit(repo);
      addTearDown(cubit.close);
      await cubit.ensureLoaded();
      final pending = Completer<SettlementHistory>();
      repo.respond = (page) =>
          page == 2 ? pending.future : Future.value(history(page));
      final page = cubit.changePage(2);
      await cubit.changePage(2);
      await cubit.refresh();
      pending.complete(history(2));
      await page;
      expect(repo.pages, [1, 2, 1]);
      expect(cubit.state.history!.pageNumber, 1);
    },
  );

  test(
    'forbidden and disposal safely clear or ignore sensitive response',
    () async {
      final repo = HistoryRepository();
      final cubit = OperatorSettlementHistoryCubit(repo);
      await cubit.ensureLoaded();
      repo.respond = (_) async => throw const PermissionFailure();
      await cubit.refresh();
      expect(cubit.state.forbidden, isTrue);
      expect(cubit.state.history, isNull);
      final pending = Completer<SettlementHistory>();
      repo.respond = (_) => pending.future;
      final request = cubit.refresh();
      await cubit.close();
      pending.complete(history(1));
      await request;
      expect(cubit.isClosed, isTrue);
    },
  );
}
