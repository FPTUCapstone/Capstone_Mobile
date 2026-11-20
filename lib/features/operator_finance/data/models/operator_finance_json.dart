import 'package:trip_mate_mobile/features/operator_finance/domain/entities/payout_settlement_history.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';

abstract final class OperatorFinanceJson {
  static RevenueReport report(Object? value) {
    final body = _map(value);
    final summary = _map(body['summary']);
    return RevenueReport(
      summary: RevenueSummary(
        grossRevenue: _money(summary, 'grossRevenue'),
        paymentsReceived: _money(summary, 'paymentsReceived'),
        discountsGiven: _money(summary, 'discountsGiven'),
        refundedAmount: _money(summary, 'refundedAmount'),
        netSales: _money(summary, 'netSales'),
        platformCommission: _money(summary, 'platformCommission'),
        netAmount: _money(summary, 'netAmount'),
        totalBookings: _integer(summary, 'totalBookings'),
        totalParticipants: _integer(summary, 'totalParticipants'),
        commissionRatePercent: _money(summary, 'commissionRatePercent'),
      ),
      chartData: List.unmodifiable(
        _list(body['chartData']).map((value) {
          final row = _map(value);
          return RevenuePeriod(
            periodKey: _text(row, 'periodKey'),
            periodLabel: _text(row, 'periodLabel'),
            grossRevenue: _money(row, 'grossRevenue'),
            commission: _money(row, 'commission'),
            netAmount: _money(row, 'netAmount'),
            refundedAmount: _money(row, 'refundedAmount'),
            bookingsCount: _integer(row, 'bookingsCount'),
          );
        }),
      ),
      tourDetails: List.unmodifiable(
        _list(body['tourDetails']).map((value) {
          final row = _map(value);
          return TourRevenue(
            tourId: _integer(row, 'tourId', minimum: 1),
            tourCode: _text(row, 'tourCode'),
            tourName: _text(row, 'tourName'),
            bookingsCount: _integer(row, 'bookingsCount'),
            participantsCount: _integer(row, 'participantsCount'),
            grossRevenue: _money(row, 'grossRevenue'),
            refundedAmount: _money(row, 'refundedAmount'),
            commission: _money(row, 'commission'),
            netAmount: _money(row, 'netAmount'),
          );
        }),
      ),
      totalToursCount: _integer(body, 'totalToursCount'),
      page: _integer(body, 'page', minimum: 1),
      pageSize: _integer(body, 'pageSize', minimum: 1, maximum: 100),
      totalPages: _integer(body, 'totalPages'),
    );
  }

  static List<RevenueTourOption> tourOptions(Object? value) =>
      List.unmodifiable(
        _list(value).map((value) {
          final row = _map(value);
          final active = row['isActive'];
          if (active is! bool) throw const FormatException();
          return RevenueTourOption(
            id: _integer(row, 'id', minimum: 1),
            code: _text(row, 'code'),
            title: _text(row, 'title'),
            isActive: active,
          );
        }),
      );

  static SettlementHistory settlementHistory(Object? value) {
    final body = _map(value);
    return SettlementHistory(
      pageNumber: _integer(body, 'pageNumber', minimum: 1),
      pageSize: _integer(body, 'pageSize', minimum: 1, maximum: 100),
      totalCount: _integer(body, 'totalCount'),
      items: List.unmodifiable(
        _list(body['items']).map((value) {
          final row = _map(value);
          final reference = row['transferReference'];
          if (!row.containsKey('transferReference') ||
              reference != null && reference is! String) {
            throw const FormatException();
          }
          final payout = _money(row, 'payoutAmount');
          if (payout < 0) throw const FormatException();
          return PayoutSettlement(
            settlementId: _nullableId(row, 'settlementId'),
            batchId: _nullableId(row, 'batchId'),
            bookingId: _integer(row, 'bookingId', minimum: 1),
            tourOperatorUserId: _integer(row, 'tourOperatorUserId', minimum: 1),
            runDate: _nullableDay(row, 'runDate'),
            kind: _text(row, 'kind'),
            payoutAmount: payout,
            status: _text(row, 'status'),
            transferReference: reference as String?,
          );
        }),
      ),
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>) throw const FormatException();
    return value;
  }

  static List<dynamic> _list(Object? value) {
    if (value is! List) throw const FormatException();
    return value;
  }

  static num _money(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! num || !value.isFinite) throw const FormatException();
    return value;
  }

  static int _integer(
    Map<String, dynamic> row,
    String key, {
    int minimum = 0,
    int? maximum,
  }) {
    final value = row[key];
    if (value is! int ||
        value < minimum ||
        maximum != null && value > maximum) {
      throw const FormatException();
    }
    return value;
  }

  static String _text(Map<String, dynamic> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) throw const FormatException();
    return value;
  }

  static int? _nullableId(Map<String, dynamic> row, String key) {
    if (!row.containsKey(key)) throw const FormatException();
    return row[key] == null ? null : _integer(row, key, minimum: 1);
  }

  static DateTime? _nullableDay(Map<String, dynamic> row, String key) {
    if (!row.containsKey(key)) throw const FormatException();
    final value = row[key];
    if (value == null) return null;
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException();
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
      throw const FormatException();
    }
    return parsed;
  }
}
