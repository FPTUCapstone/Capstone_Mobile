import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_alert_banner.dart';

void main() {
  testWidgets('weather warning exposes the skip shortcut', (tester) async {
    var skipRequests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripAlertBanner(
            alert: TripAlert(
              id: '51',
              title: 'Heavy rain',
              description: 'Heavy rain is forecast at the next stop.',
              severity: AlertSeverity.warning,
              type: TripAlertType.weather,
              affectedStopName: 'My Khe Beach',
              timestamp: DateTime.utc(2026, 10, 28, 9),
              messageCode: 'trip_alert.severe_weather',
              rainIntensityMmPerHour: 12,
              canSkipAffectedStop: true,
            ),
            onDismiss: () {},
            onSkipAffectedStop: () => skipRequests++,
          ),
        ),
      ),
    );

    expect(find.text('Skip this stop'), findsOneWidget);
    await tester.tap(find.text('Skip this stop'));
    expect(skipRequests, 1);
  });

  testWidgets('extreme rain does not assume the affected stop is Outdoor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripAlertBanner(
            alert: TripAlert(
              id: '52',
              title: 'Extreme rain',
              description: 'Extreme rain is forecast at the next stop.',
              severity: AlertSeverity.warning,
              type: TripAlertType.weather,
              affectedStopName: 'Museum',
              timestamp: DateTime.utc(2026, 10, 28, 9),
              messageCode: 'trip_alert.severe_weather',
              rainIntensityMmPerHour: 55,
            ),
            onDismiss: () {},
            onSkipAffectedStop: () {},
          ),
        ),
      ),
    );

    expect(find.text('Skip this stop'), findsNothing);
  });

  testWidgets('reviewed Outdoor extreme rain offers the skip shortcut', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripAlertBanner(
            alert: TripAlert(
              id: '54',
              title: 'Extreme rain',
              description: 'Extreme rain at the beach.',
              severity: AlertSeverity.warning,
              type: TripAlertType.weather,
              affectedStopName: 'My Khe Beach',
              timestamp: DateTime.utc(2026, 10, 28, 9),
              messageCode: 'trip_alert.severe_weather',
              rainIntensityMmPerHour: 55,
              canSkipAffectedStop: true,
            ),
            onDismiss: () {},
            onSkipAffectedStop: () {},
          ),
        ),
      ),
    );

    expect(find.text('Skip this stop'), findsOneWidget);
  });

  testWidgets('thunderstorm at an unreviewed stop has no skip shortcut', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripAlertBanner(
            alert: TripAlert(
              id: '53',
              title: 'Thunderstorm',
              description: 'Thunderstorm at the destination.',
              severity: AlertSeverity.warning,
              type: TripAlertType.weather,
              affectedStopName: 'Museum',
              timestamp: DateTime.utc(2026, 10, 28, 9),
              messageCode: 'trip_alert.severe_weather',
              rainIntensityMmPerHour: 20,
              canSkipAffectedStop: false,
            ),
            onDismiss: () {},
            onSkipAffectedStop: () {},
          ),
        ),
      ),
    );

    expect(find.text('Skip this stop'), findsNothing);
  });
}
