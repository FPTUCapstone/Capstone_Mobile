import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_finance/data/models/operator_finance_json.dart';

Map<String, dynamic> reportJson({num net = 4500}) => {
  'summary': {
    'grossRevenue': 10000,
    'paymentsReceived': 10000,
    'discountsGiven': 0,
    'refundedAmount': 5000,
    'netSales': 5000,
    'platformCommission': 500,
    'netAmount': net,
    'totalBookings': 1,
    'totalParticipants': 2,
    'commissionRatePercent': 10,
  },
  'chartData': [
    {
      'periodKey': '2026-11',
      'periodLabel': '2026-11',
      'grossRevenue': 10000,
      'commission': 500,
      'netAmount': net,
      'refundedAmount': 5000,
      'bookingsCount': 1,
    },
  ],
  'tourDetails': [
    {
      'tourId': 7,
      'tourCode': 'TOUR-7',
      'tourName': 'Tour history',
      'bookingsCount': 1,
      'participantsCount': 2,
      'grossRevenue': 10000,
      'refundedAmount': 5000,
      'commission': 500,
      'netAmount': net,
    },
  ],
  'totalToursCount': 1,
  'page': 1,
  'pageSize': 10,
  'totalPages': 1,
};

void main() {
  test(
    'preserves BE values and signed net, no projection or derived fields',
    () {
      for (final net in [4500, -1250.5]) {
        final report = OperatorFinanceJson.report(reportJson(net: net));
        expect(report.summary.netAmount, net);
        expect(report.chartData.single.netAmount, net);
        expect(report.tourDetails.single.netAmount, net);
        expect(report.summary.totalParticipants, 2);
      }
    },
  );

  test('missing or malformed required data does not silently become zero', () {
    final missing = reportJson();
    (missing['summary'] as Map).remove('netAmount');
    expect(() => OperatorFinanceJson.report(missing), throwsFormatException);
    final wrong = reportJson()..['chartData'] = 'not a list';
    expect(() => OperatorFinanceJson.report(wrong), throwsFormatException);
    final nonFinite = reportJson(net: double.infinity);
    expect(() => OperatorFinanceJson.report(nonFinite), throwsFormatException);
  });

  test('empty response and historical tour option are valid', () {
    final empty = reportJson();
    final summary = empty['summary'] as Map<String, dynamic>;
    for (final key in summary.keys.toList()) {
      summary[key] = 0;
    }
    empty.addAll({
      'chartData': <Object>[],
      'tourDetails': <Object>[],
      'totalToursCount': 0,
      'totalPages': 0,
    });
    expect(OperatorFinanceJson.report(empty).summary.totalBookings, 0);
    final options = OperatorFinanceJson.tourOptions([
      {'id': 7, 'code': 'TOUR-00007', 'title': 'Historical', 'isActive': false},
    ]);
    expect(options.single.isActive, isFalse);
  });

  test(
    'settlements preserve three kinds, unknown values and nullable details',
    () {
      final result = OperatorFinanceJson.settlementHistory({
        'pageNumber': 2,
        'pageSize': 10,
        'totalCount': 14,
        'items': [
          for (final kind in ['Advance', 'Final', 'Cancellation', 'FutureKind'])
            {
              'settlementId': null,
              'batchId': null,
              'bookingId': 9,
              'tourOperatorUserId': 11,
              'runDate': null,
              'kind': kind,
              'payoutAmount': 0,
              'status': kind == 'Final' ? 'Resolved' : 'FutureStatus',
              'transferReference': null,
            },
        ],
      });
      expect(result.pageNumber, 2);
      expect(result.items.map((item) => item.kind), [
        'Advance',
        'Final',
        'Cancellation',
        'FutureKind',
      ]);
      expect(result.items[1].status, 'Resolved');
      expect(result.items.first.runDate, isNull);
      expect(result.items.first.transferReference, isNull);
    },
  );

  test('run date remains calendar day and impossible dates are rejected', () {
    Map<String, dynamic> payload(String date) => {
      'pageNumber': 1,
      'pageSize': 10,
      'totalCount': 1,
      'items': [
        {
          'settlementId': 4,
          'batchId': 5,
          'bookingId': 9,
          'tourOperatorUserId': 11,
          'runDate': date,
          'kind': 'Cancellation',
          'payoutAmount': 100,
          'status': 'Settled',
          'transferReference': 'REF-123',
        },
      ],
    };
    expect(
      OperatorFinanceJson.settlementHistory(
        payload('2026-11-01'),
      ).items.single.runDate,
      DateTime(2026, 11, 1),
    );
    expect(
      () => OperatorFinanceJson.settlementHistory(payload('2026-02-30')),
      throwsFormatException,
    );
  });
}
