import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/trip_alerts_page.dart';
import '../../../../support/trip_alert_test_data.dart';

void main() {
  group('TripAlertsPage', () {
    testWidgets('renders active alerts with severity chips and descriptions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TripAlertsPage(
            itineraryId: 101,
            alerts: TripAlertTestData.sampleAlerts(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cảnh báo chuyến đi'), findsOneWidget);
      expect(find.textContaining('cảnh báo đang hoạt động'), findsOneWidget);
      expect(find.textContaining('Severe weather warning'), findsOneWidget);
      expect(find.textContaining('Schedule delay detected'), findsOneWidget);
      expect(find.textContaining('POI closed for maintenance'), findsOneWidget);
      expect(find.textContaining('Route deviation detected'), findsOneWidget);

      expect(find.text('KHẨN CẤP'), findsWidgets);
      expect(find.text('CẢNH BÁO'), findsOneWidget);
      expect(find.text('THÔNG BÁO'), findsOneWidget);
    });

    testWidgets('renders empty state when there are no alerts in production', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: TripAlertsPage(itineraryId: 101)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Không có cảnh báo nào cho chuyến đi này.'),
        findsOneWidget,
      );
      expect(find.textContaining('0 cảnh báo đang hoạt động'), findsOneWidget);
    });
  });
}
