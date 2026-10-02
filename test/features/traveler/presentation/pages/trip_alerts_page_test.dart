import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/trip_alerts_page.dart';

void main() {
  group('TripAlertsPage', () {
    testWidgets('renders active alerts with severity chips and descriptions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: TripAlertsPage(
            itineraryId: 101,
            alerts: ActiveTripDemoFixtures.createSampleAlerts(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trip Alerts'), findsOneWidget);
      expect(find.textContaining('active alerts logged'), findsOneWidget);
      expect(find.textContaining('Severe weather warning'), findsOneWidget);
      expect(find.textContaining('Schedule delay detected'), findsOneWidget);
      expect(find.textContaining('POI closed for maintenance'), findsOneWidget);
      expect(find.textContaining('Route deviation detected'), findsOneWidget);

      expect(find.text('CRITICAL'), findsWidgets);
      expect(find.text('WARNING'), findsOneWidget);
      expect(find.text('NOTICE'), findsOneWidget);
    });

    testWidgets('renders empty state when there are no alerts', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TripAlertsPage(itineraryId: 101, alerts: [])),
      );
      await tester.pumpAndSettle();

      expect(find.text('No alerts found for this trip.'), findsOneWidget);
    });
  });
}
