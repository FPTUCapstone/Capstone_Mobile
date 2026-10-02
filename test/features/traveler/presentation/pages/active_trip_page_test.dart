import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/active_trip_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/navigation_map_canvas.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/reroute_proposal_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_alert_banner.dart';

void main() {
  Widget buildTestWidget({ActiveTripCubit? cubit, bool isDemoMode = false}) {
    return MaterialApp(
      home: ActiveTripPage(
        itineraryId: 101,
        title: 'Đà Nẵng City Explorer',
        cubit: cubit,
        isDemoMode: isDemoMode,
      ),
    );
  }

  group('ActiveTripPage', () {
    testWidgets(
      'renders maneuver banner, map canvas with pending banner, and stop ETA',
      (tester) async {
        final cubit = ActiveTripCubit(
          itineraryId: 101,
          itineraryTitle: 'Đà Nẵng City Explorer',
          initialWaypoints: ActiveTripDemoFixtures.createDefaultWaypoints(),
          initialAlerts: const [],
          isDemoMode: true,
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDemoMode: true),
        );
        await tester.pumpAndSettle();

        // Maneuver banner
        expect(find.textContaining('Lê Văn Hiến'), findsOneWidget);

        // Map canvas illustration preview banner
        expect(find.byType(NavigationMapCanvas), findsOneWidget);
        expect(find.textContaining('MAP INTEGRATION PENDING'), findsOneWidget);

        // Current waypoint information (rendered in pin and bottom panel)
        expect(find.text('Marble Mountains (Ngũ Hành Sơn)'), findsWidgets);
        expect(find.textContaining('Remaining stops'), findsOneWidget);

        // Verify production UI does NOT contain manual "Arrived" action
        // Arrival is detected automatically by the system/GPS per SRS UC-13
        expect(find.text('Arrived at this stop'), findsNothing);
        expect(find.text('I have arrived'), findsNothing);
        expect(find.byKey(const Key('manual_arrived_button')), findsNothing);

        await cubit.close();
      },
    );

    testWidgets(
      'DEMO_ONLY controls are isolated and allow testing arrival progression',
      (tester) async {
        final cubit = ActiveTripCubit(
          itineraryId: 101,
          itineraryTitle: 'Đà Nẵng City Explorer',
          initialWaypoints: ActiveTripDemoFixtures.createDefaultWaypoints(),
          initialAlerts: const [],
          isDemoMode: true,
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDemoMode: true),
        );
        await tester.pumpAndSettle();

        // Demo controls toggle exists
        final demoToggle = find.byTooltip('DEMO_ONLY Controls');
        expect(demoToggle, findsOneWidget);

        await tester.tap(demoToggle);
        await tester.pumpAndSettle();

        expect(find.text('DEMO_ONLY Test Controls'), findsOneWidget);

        // Inside demo controls: Simulate GPS arrival action exists
        final simulateArrival = find.text('Simulate Stop Arrival');
        expect(simulateArrival, findsOneWidget);

        // Tap simulate GPS arrival
        await tester.tap(simulateArrival);
        await tester.pumpAndSettle();

        // Next waypoint is now active
        expect(find.text('Cơm Gà Bà Buội'), findsWidgets);
        expect(find.textContaining('Remaining stops'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets('DEMO controls are absent when isDemoMode is false', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(isDemoMode: false));
      await tester.pumpAndSettle();

      expect(find.byTooltip('DEMO_ONLY Controls'), findsNothing);
      expect(find.byIcon(Icons.build_circle_outlined), findsNothing);
    });

    testWidgets(
      'DEMO controls appear when explicitly constructed with isDemoMode true',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(isDemoMode: true));
        await tester.pumpAndSettle();

        expect(find.byTooltip('DEMO_ONLY Controls'), findsOneWidget);
        expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'renders active alert banner and dismissing it retains history',
      (tester) async {
        final cubit = ActiveTripCubit(
          itineraryId: 101,
          itineraryTitle: 'Đà Nẵng City Explorer',
          initialWaypoints: ActiveTripDemoFixtures.createDefaultWaypoints(),
          initialAlerts: ActiveTripDemoFixtures.createSampleAlerts(),
          isDemoMode: true,
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDemoMode: true),
        );
        await tester.pumpAndSettle();

        // Alert banner is visible
        expect(find.byType(TripAlertBanner), findsOneWidget);
        expect(find.text('CRITICAL ALERT'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets(
      'reroute proposal sheet displays comparison and strict consent buttons',
      (tester) async {
        final cubit = ActiveTripCubit(
          itineraryId: 101,
          itineraryTitle: 'Đà Nẵng City Explorer',
          initialWaypoints: ActiveTripDemoFixtures.createDefaultWaypoints(),
          initialAlerts: const [],
          isDemoMode: true,
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDemoMode: true),
        );
        await tester.pumpAndSettle();

        // Present proposal
        cubit.openRerouteProposal(
          ActiveTripDemoFixtures.createSampleRerouteProposal(),
        );
        await tester.pumpAndSettle();

        // Reroute proposal sheet is rendered
        expect(find.byType(RerouteProposalSheet), findsOneWidget);
        expect(find.text('Suggested Route Change'), findsOneWidget);

        // Explicit consent buttons exist (no auto-apply)
        expect(find.text('Accept Re-routing'), findsOneWidget);
        expect(find.text('Keep Current Route'), findsOneWidget);

        // Declining proposal closes sheet and retains route
        await tester.tap(find.text('Keep Current Route'));
        await tester.pumpAndSettle();

        expect(find.byType(RerouteProposalSheet), findsNothing);
        expect(cubit.state.itineraryVersion, 1);

        await cubit.close();
      },
    );

    testWidgets('renders completion summary when all waypoints are reached', (
      tester,
    ) async {
      final cubit = ActiveTripCubit(
        itineraryId: 101,
        itineraryTitle: 'Đà Nẵng City Explorer',
        initialWaypoints: ActiveTripDemoFixtures.createDefaultWaypoints(),
        initialAlerts: const [],
        isDemoMode: true,
      );

      await tester.pumpWidget(buildTestWidget(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();

      // Simulate reaching all 5 stops
      cubit.onSystemDetectedArrival();
      cubit.onSystemDetectedArrival();
      cubit.onSystemDetectedArrival();
      cubit.onSystemDetectedArrival();
      cubit.onSystemDetectedArrival();
      await tester.pumpAndSettle();

      expect(find.text('Trip Completed!'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);

      // Dismiss dialog
      Navigator.of(tester.element(find.text('Trip Completed!'))).pop();
      await tester.pumpAndSettle();

      await cubit.close();
    });
  });
}
