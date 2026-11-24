import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_finance/data/datasources/operator_finance_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_finance/data/models/operator_finance_json.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/repositories/operator_finance_repository.dart';

final class OperatorFinanceRepositoryImpl implements OperatorFinanceRepository {
  const OperatorFinanceRepositoryImpl(this._remote);
  final OperatorFinanceRemoteDataSource _remote;

  @override
  Future<RevenueReport> loadReport(RevenueQuery query) async {
    if (!query.isValid) throw ValidationFailure(query.validationError!);
    final report = await _parse(
      () => _remote.loadReport(query),
      OperatorFinanceJson.report,
    );
    if (report.page != query.page || report.pageSize != query.pageSize) {
      throw const ServerFailure();
    }
    return report;
  }

  @override
  Future<List<RevenueTourOption>> loadTourOptions() =>
      _parse(_remote.loadTourOptions, OperatorFinanceJson.tourOptions);

  @override
  Future<SettlementHistory> loadSettlementHistory({
    int page = 1,
    int pageSize = 10,
  }) async {
    if (page < 1 || pageSize < 1 || pageSize > 100) {
      throw const ValidationFailure('Thông tin trang không hợp lệ.');
    }
    final history = await _parse(
      () => _remote.loadSettlementHistory(page: page, pageSize: pageSize),
      OperatorFinanceJson.settlementHistory,
    );
    if (history.pageNumber != page || history.pageSize != pageSize) {
      throw const ServerFailure();
    }
    return history;
  }

  Future<T> _parse<T>(
    Future<Object?> Function() load,
    T Function(Object?) parse,
  ) async {
    final body = await load();
    try {
      return parse(body);
    } on FormatException {
      throw const ServerFailure();
    }
  }
}
