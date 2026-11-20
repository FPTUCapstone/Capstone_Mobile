import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';

abstract interface class OperatorFinanceRepository {
  Future<RevenueReport> loadReport(RevenueQuery query);
  Future<List<RevenueTourOption>> loadTourOptions();
  Future<SettlementHistory> loadSettlementHistory({
    int page = 1,
    int pageSize = 10,
  });
}
