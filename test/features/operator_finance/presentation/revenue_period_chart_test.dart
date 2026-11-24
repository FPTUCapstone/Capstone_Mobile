import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_report.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/widgets/revenue_period_chart.dart';

RevenuePeriod period(String key, num net) => RevenuePeriod(
  periodKey: key,
  periodLabel: key,
  grossRevenue: 10000,
  commission: 1000,
  netAmount: net,
  refundedAmount: 0,
  bookingsCount: 1,
);

void main() {
  testWidgets('keeps signed values and zero axis without recomputing net', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RevenuePeriodChart(
              periods: [period('2026-10', -4500), period('2026-11', 7000)],
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('-4.500 VNĐ'), findsWidgets);
    expect(find.byKey(const Key('revenue-zero-axis-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('revenue-period-1')));
    await tester.pump();
    expect(find.textContaining('7.000 VNĐ'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all-zero periods render safely at narrow width with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: RevenuePeriodChart(periods: [period('2026-11', 0)]),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('0 VNĐ'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'many periods use lazy scrolling and do not manufacture buckets',
    (tester) async {
      final values = List.generate(1000, (i) => period('period-$i', i));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RevenuePeriodChart(periods: values),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('revenue-period-0')), findsOneWidget);
      expect(find.byKey(const Key('revenue-period-999')), findsNothing);
      expect(find.byType(ListView), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty periods have a truthful empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RevenuePeriodChart(periods: [])),
      ),
    );
    expect(find.text('Chưa có dữ liệu biểu đồ trong kỳ này.'), findsOneWidget);
    expect(find.byKey(const Key('revenue-period-0')), findsNothing);
  });
}
