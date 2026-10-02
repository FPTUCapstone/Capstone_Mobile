import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/active_trip_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/navigation_map_canvas.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/reroute_proposal_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_alert_banner.dart';

void main() {
  Widget buildTestWidget({
    ActiveTripCubit? cubit,
    String? title,
    ItineraryRepository? repository,
    bool isDemoMode = false,
  }) {
    return MaterialApp(
      home: ActiveTripPage(
        itineraryId: 101,
        title: title,
        cubit: cubit,
        repository: repository,
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

    testWidgets(
      'production mode (isDemoMode: false) does NOT render DEMO_ONLY Controls banner',
      (tester) async {
        final cubit = ActiveTripCubit(
          itineraryId: 101,
          itineraryTitle: 'Real Trip',
          isDemoMode: false,
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDemoMode: false),
        );
        await tester.pumpAndSettle();

        expect(find.text('DEMO_ONLY Controls'), findsNothing);
        expect(find.byTooltip('DEMO_ONLY Controls'), findsNothing);
        expect(find.byIcon(Icons.build_circle_outlined), findsNothing);

        await cubit.close();
      },
    );

    testWidgets(
      'demo mode (isDemoMode: true) DOES render DEMO_ONLY Controls banner',
      (tester) async {
        final cubit = ActiveTripCubit(
          itineraryId: 101,
          itineraryTitle: 'Demo Trip',
          isDemoMode: true,
        );

        await tester.pumpWidget(
          buildTestWidget(cubit: cubit, isDemoMode: true),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip('DEMO_ONLY Controls'), findsOneWidget);
        expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);

        await tester.tap(find.byIcon(Icons.build_circle_outlined));
        await tester.pumpAndSettle();

        expect(find.text('DEMO_ONLY Test Controls'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets(
      'renders dismissible TripAlertBanner when undismissed alert is present',
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

        expect(find.byType(TripAlertBanner), findsOneWidget);
        expect(find.textContaining('Severe weather warning'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets(
      'shows RerouteProposalSheet when proposal is triggered and handles accept',
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

        expect(find.byType(RerouteProposalSheet), findsNothing);

        cubit.openRerouteProposal();
        await tester.pumpAndSettle();

        expect(find.byType(RerouteProposalSheet), findsOneWidget);
        expect(find.text('Suggested Route Change'), findsOneWidget);
        expect(find.text('Reason for Re-routing'), findsOneWidget);

        await tester.tap(find.text('Accept Re-routing'));
        await tester.pumpAndSettle();

        expect(find.byType(RerouteProposalSheet), findsNothing);
        expect(cubit.state.itineraryVersion, 2);

        await cubit.close();
      },
    );

    testWidgets(
      'declining RerouteProposalSheet retains original route without incrementing version',
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

        cubit.openRerouteProposal();
        await tester.pumpAndSettle();

        expect(find.byType(RerouteProposalSheet), findsOneWidget);

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

    testWidgets(
      'direct Active Trip route without state.extra does NOT fabricate "Đà Nẵng Day Trip"',
      (tester) async {
        final repo = _FakeItineraryRepository(
          detail: _createSampleDetail(
            itineraryId: 101,
            title: 'Hanoi Heritage Tour',
          ),
        );

        await tester.pumpWidget(
          buildTestWidget(title: null, repository: repo, isDemoMode: false),
        );
        await tester.pumpAndSettle();

        expect(find.text('Đà Nẵng Day Trip'), findsNothing);
        expect(find.text('Đà Nẵng City Explorer'), findsNothing);
        expect(find.text('Hanoi Heritage Tour'), findsOneWidget);
      },
    );

    testWidgets('shows loading state while metadata is being retrieved', (
      tester,
    ) async {
      final completer = Completer<ItineraryDetail>();
      final repo = _CompleterItineraryRepository(completer);

      await tester.pumpWidget(
        buildTestWidget(title: null, repository: repo, isDemoMode: false),
      );
      await tester.pump();

      expect(find.text('Loading trip...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        _createSampleDetail(itineraryId: 101, title: 'Saigon Explorer'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Saigon Explorer'), findsOneWidget);
    });

    testWidgets('shows error state when metadata retrieval fails', (
      tester,
    ) async {
      final repo = _FakeItineraryRepository(shouldThrow: true);

      await tester.pumpWidget(
        buildTestWidget(title: null, repository: repo, isDemoMode: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load trip'), findsOneWidget);
      expect(find.text('Trip information unavailable.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Go back'), findsOneWidget);
    });

    testWidgets(
      'explicit demo mode may show fixture title when no title passed',
      (tester) async {
        await tester.pumpWidget(buildTestWidget(title: null, isDemoMode: true));
        await tester.pumpAndSettle();

        expect(find.text('Đà Nẵng Day Trip'), findsOneWidget);
      },
    );
  });
}

ItineraryDetail _createSampleDetail({
  required int itineraryId,
  required String title,
}) {
  return ItineraryDetail(
    itineraryId: itineraryId,
    schedulingRequestId: 1,
    title: title,
    version: 1,
    status: 'Active',
    validFrom: null,
    validTo: null,
    canManage: true,
    totalEstimatedCost: 150000,
    totalDurationMinutes: 180,
    items: const [],
  );
}

final class _FakeItineraryRepository implements ItineraryRepository {
  _FakeItineraryRepository({this.detail, this.shouldThrow = false});

  final ItineraryDetail? detail;
  final bool shouldThrow;

  @override
  Future<ItineraryDetail> getById(int itineraryId) async {
    if (shouldThrow) {
      throw Exception('Server unreachable');
    }
    return detail ??
        _createSampleDetail(itineraryId: itineraryId, title: 'Sample Trip');
  }

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> accept(int itineraryId) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> adjustItems({
    required int itineraryId,
    required List<int> orderedVisitPoiIds,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}

final class _CompleterItineraryRepository implements ItineraryRepository {
  _CompleterItineraryRepository(this.completer);

  final Completer<ItineraryDetail> completer;

  @override
  Future<ItineraryDetail> getById(int itineraryId) => completer.future;

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> accept(int itineraryId) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> adjustItems({
    required int itineraryId,
    required List<int> orderedVisitPoiIds,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}
