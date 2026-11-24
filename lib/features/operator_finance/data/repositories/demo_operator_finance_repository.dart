import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/repositories/operator_finance_repository.dart';

/// Explicit demo only. Never a fallback for a failed live request.
final class DemoOperatorFinanceRepository implements OperatorFinanceRepository {
  const DemoOperatorFinanceRepository();

  @override
  Future<List<RevenueTourOption>> loadTourOptions() async => const [
    RevenueTourOption(
      id: 101,
      code: 'DEMO-101',
      title: 'Tour minh họa',
      isActive: true,
    ),
  ];

  @override
  Future<RevenueReport> loadReport(RevenueQuery query) async {
    final empty = query.tourId != null && query.tourId != 101;
    return RevenueReport(
      summary: RevenueSummary(
        grossRevenue: empty ? 0 : 10000,
        paymentsReceived: empty ? 0 : 10000,
        discountsGiven: 0,
        refundedAmount: empty ? 0 : 5000,
        netSales: empty ? 0 : 5000,
        platformCommission: empty ? 0 : 500,
        netAmount: empty ? 0 : 4500,
        totalBookings: empty ? 0 : 1,
        totalParticipants: empty ? 0 : 1,
        commissionRatePercent: 10,
      ),
      chartData: empty
          ? []
          : [
              RevenuePeriod(
                periodKey: 'demo-period',
                periodLabel: 'Kỳ minh họa',
                grossRevenue: 10000,
                commission: 500,
                netAmount: 4500,
                refundedAmount: 5000,
                bookingsCount: 1,
              ),
            ],
      tourDetails: empty || query.page > 1
          ? []
          : const [
              TourRevenue(
                tourId: 101,
                tourCode: 'DEMO-101',
                tourName: 'Tour minh họa',
                bookingsCount: 1,
                participantsCount: 1,
                grossRevenue: 10000,
                refundedAmount: 5000,
                commission: 500,
                netAmount: 4500,
              ),
            ],
      totalToursCount: empty ? 0 : 1,
      page: query.page,
      pageSize: query.pageSize,
      totalPages: empty ? 0 : 1,
    );
  }

  @override
  Future<SettlementHistory> loadSettlementHistory({
    int page = 1,
    int pageSize = 10,
  }) async => SettlementHistory(
    pageNumber: page,
    pageSize: pageSize,
    totalCount: 3,
    items: page > 1
        ? []
        : [
            PayoutSettlement(
              settlementId: 3,
              batchId: 2,
              bookingId: 101,
              tourOperatorUserId: 1,
              runDate: DateTime(2026, 11, 19),
              kind: 'Cancellation',
              payoutAmount: 1000,
              status: 'Settled',
              transferReference: 'DEMO-TRANSFER-3',
            ),
            PayoutSettlement(
              settlementId: 2,
              batchId: 2,
              bookingId: 102,
              tourOperatorUserId: 1,
              runDate: DateTime(2026, 11, 19),
              kind: 'Final',
              payoutAmount: 2000,
              status: 'Scheduled',
              transferReference: null,
            ),
            PayoutSettlement(
              settlementId: 1,
              batchId: 1,
              bookingId: 101,
              tourOperatorUserId: 1,
              runDate: DateTime(2026, 11, 18),
              kind: 'Advance',
              payoutAmount: 7000,
              status: 'Settled',
              transferReference: 'DEMO-TRANSFER-1',
            ),
          ],
  );
}
