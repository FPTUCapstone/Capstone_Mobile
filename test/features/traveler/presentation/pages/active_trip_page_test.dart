import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/navigation_location_tracker.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/demo_navigation_session_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/active_trip_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/navigation_map_canvas.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/reroute_proposal_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_alert_banner.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_alerts_sheet.dart';

import '../cubit/active_trip_cubit_test.dart';

void main() {
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  // The existing RerouteProposalSheet (UC-15) is laid out for wider screens.
  void useWideSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Widget buildPage({
    ActiveTripCubit? cubit,
    String? title,
    ItineraryRepository? repository,
    FakeSessionRepository? sessionRepository,
    NavigationLocationTracker? locationTracker,
    bool isDemoMode = false,
  }) {
    return MaterialApp(
      home: ActiveTripPage(
        itineraryId: 101,
        title: title,
        cubit: cubit,
        repository: repository,
        sessionRepository: sessionRepository,
        locationTracker: locationTracker,
        useMapbox: false,
        isDemoMode: isDemoMode,
      ),
    );
  }

  Future<ActiveTripCubit> startedDemoCubit() async {
    final cubit = ActiveTripCubit(
      itineraryId: 101,
      itineraryTitle: 'Đà Nẵng City Explorer',
      sessionRepository: DemoNavigationSessionRepository(),
      initialAlerts: const [],
      isDemoMode: true,
    );
    await cubit.start();
    return cubit;
  }

  group('ActiveTripPage navigation', () {
    testWidgets(
      'renders the preview map, target stop, and manual arrival action',
      (tester) async {
        usePhoneSurface(tester);
        final cubit = await startedDemoCubit();

        await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
        await tester.pumpAndSettle();

        expect(find.byType(NavigationMapCanvas), findsOneWidget);
        expect(find.textContaining('MAPBOX NOT CONFIGURED'), findsOneWidget);
        expect(find.text('Marble Mountains (Ngũ Hành Sơn)'), findsOneWidget);
        expect(find.text('SUGGESTED NEXT'), findsOneWidget);
        expect(find.text('MANDATORY'), findsOneWidget);
        expect(find.text('0 of 5 stops reached'), findsOneWidget);
        expect(find.byKey(const Key('manual_arrived_button')), findsOneWidget);
        expect(find.text('I have arrived'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets(
      'manual arrival asks for confirmation, then shows the exploring card',
      (tester) async {
        usePhoneSurface(tester);
        final cubit = await startedDemoCubit();
        await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('manual_arrived_button')));
        await tester.pumpAndSettle();
        expect(find.text('Mark as arrived?'), findsOneWidget);

        await tester.tap(find.text("I'm here"));
        await tester.pumpAndSettle();

        expect(
          find.text('You are at Marble Mountains (Ngũ Hành Sơn)'),
          findsOneWidget,
        );
        expect(find.text('EXPLORING'), findsOneWidget);
        expect(find.text('1 of 5 stops reached'), findsOneWidget);

        await tester.tap(find.byKey(const Key('depart_button')));
        await tester.pumpAndSettle();

        expect(find.text('Cơm Gà Bà Buội'), findsOneWidget);
        expect(find.text('NAVIGATING'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets('GPS-detected arrival prompt can be confirmed or postponed', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final cubit = await startedDemoCubit();
      await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('DEMO_ONLY Controls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate Stop Arrival'));
      await tester.pumpAndSettle();

      expect(find.text('Have you arrived?'), findsOneWidget);
      await tester.tap(find.text('Not yet'));
      await tester.pumpAndSettle();
      expect(cubit.state.arrivalPromptItemId, isNull);
      expect(cubit.state.isExploring, isFalse);

      cubit.demoSimulateArrivalAtNextStop();
      await tester.pumpAndSettle();
      await tester.tap(find.text("Yes, I'm here"));
      await tester.pumpAndSettle();

      expect(cubit.state.isExploring, isTrue);
      expect(
        find.text('Arrived at Marble Mountains (Ngũ Hành Sơn).'),
        findsOneWidget,
      );

      await cubit.close();
    });

    testWidgets('skipping warns about mandatory stops and moves on', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final cubit = await startedDemoCubit();
      await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('skip_target_button')));
      await tester.pumpAndSettle();

      expect(find.text('Skip this stop?'), findsOneWidget);
      expect(
        find.textContaining('This is a mandatory stop in your itinerary.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Skip stop'));
      await tester.pumpAndSettle();

      expect(find.text('Cơm Gà Bà Buội'), findsOneWidget);
      expect(cubit.state.isExploring, isFalse);

      await cubit.close();
    });

    testWidgets('finishing confirms unvisited stops and shows the summary', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final cubit = await startedDemoCubit();
      await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('finish_trip_button')));
      await tester.pumpAndSettle();

      expect(find.text('Finish this trip?'), findsOneWidget);
      expect(
        find.textContaining('5 stops have not been visited'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Finish trip'));
      await tester.pumpAndSettle();

      expect(find.text('Navigation ended'), findsOneWidget);
      expect(find.textContaining('You reached 0 of 5 stops'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);

      await cubit.close();
    });

    testWidgets('the stop list shows statuses and per-stop actions', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final cubit = await startedDemoCubit();
      await cubit.skipItem(1002);
      await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View all stops'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Skipped'), findsOneWidget);
      expect(find.textContaining('Heading here'), findsOneWidget);

      await tester.tap(find.byKey(const Key('stop_actions_1003')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Navigate here'));
      await tester.pumpAndSettle();

      expect(cubit.state.targetItemId, 1003);

      await cubit.close();
    });

    testWidgets('GPS ticks do not rebuild the shell; session changes do', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final cubit = await startedDemoCubit();
      await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();

      final before = tester.widget<NavigationMapCanvas>(
        find.byType(NavigationMapCanvas),
      );

      cubit.updatePosition(
        NavigationPosition(
          coordinate: const NavigationCoordinate(
            latitude: 16.0544,
            longitude: 108.2022,
          ),
          timestamp: DateTime.now(),
        ),
      );
      await tester.pump();
      final afterGps = tester.widget<NavigationMapCanvas>(
        find.byType(NavigationMapCanvas),
      );
      expect(identical(before, afterGps), isTrue);
      await tester.pump();
      expect(find.textContaining('(straight line)'), findsOneWidget);

      await cubit.skipItem(1001);
      await tester.pump();
      final afterSkip = tester.widget<NavigationMapCanvas>(
        find.byType(NavigationMapCanvas),
      );
      expect(identical(afterGps, afterSkip), isFalse);

      await cubit.close();
    });

    testWidgets('toggling the stop list does not rebuild the shell', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final cubit = await startedDemoCubit();
      await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();
      final before = tester.widget<NavigationMapCanvas>(
        find.byType(NavigationMapCanvas),
      );

      await tester.tap(find.text('View all stops'));
      await tester.pumpAndSettle();
      expect(find.text('Hide stops'), findsOneWidget);
      await tester.tap(find.text('Hide stops'));
      await tester.pumpAndSettle();

      expect(find.text('View all stops'), findsOneWidget);
      expect(
        identical(
          before,
          tester.widget<NavigationMapCanvas>(find.byType(NavigationMapCanvas)),
        ),
        isTrue,
      );

      await cubit.close();
    });

    testWidgets('location permission denial offers settings and retry', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final tracker = FakeLocationTracker()
        ..access = NavigationLocationAccess.denied;
      addTearDown(tracker.dispose);

      await tester.pumpWidget(
        buildPage(
          title: 'Real Trip',
          sessionRepository: FakeSessionRepository(),
          locationTracker: tracker,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location permission required'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('ActiveTripPage start states', () {
    testWidgets('shows a specific error when the trip cannot start', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final sessions = FakeSessionRepository()
        ..startFailure = const NavigationFailure(
          'Only an Active itinerary can be navigated. Accept the itinerary first.',
          reason: NavigationFailureReason.itineraryNotActive,
        );

      await tester.pumpWidget(
        buildPage(title: 'Real Trip', sessionRepository: sessions),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to start navigation'), findsOneWidget);
      expect(
        find.text(
          'Only an Active itinerary can be navigated. Accept the itinerary first.',
        ),
        findsOneWidget,
      );

      // Retrying cannot make the itinerary Active: only "Go back" is offered.
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Go back'), findsOneWidget);
    });

    testWidgets('offers Retry when the start failed for a network reason', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final sessions = FakeSessionRepository()
        ..startFailure = const NetworkFailure();

      await tester.pumpWidget(
        buildPage(title: 'Real Trip', sessionRepository: sessions),
      );
      await tester.pumpAndSettle();

      expect(find.text('Please check your connection.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Marble Mountains (Ngũ Hành Sơn)'), findsOneWidget);
    });

    testWidgets('offers Resume or End when another trip is in progress', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final sessions = FakeSessionRepository()
        ..startFailure = const NavigationFailure(
          'You already have a trip in progress.',
          reason: NavigationFailureReason.activeSessionExists,
          activeSessionId: 77,
        )
        ..others[77] = ActiveTripDemoFixtures.createDemoSession(
          itineraryId: 55,
          sessionId: 77,
        );

      await tester.pumpWidget(
        buildPage(title: 'Real Trip', sessionRepository: sessions),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('You are already navigating another trip'),
        findsOneWidget,
      );
      expect(find.textContaining('Itinerary #55'), findsOneWidget);
      expect(find.text('Resume that trip'), findsOneWidget);

      await tester.tap(find.text('End it and start this trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('End and start'));
      await tester.pumpAndSettle();

      expect(sessions.calls, contains('complete:77'));
      expect(find.text('Marble Mountains (Ngũ Hành Sơn)'), findsOneWidget);
    });

    testWidgets('resuming the same trip tells the Traveler', (tester) async {
      usePhoneSurface(tester);
      final sessions = FakeSessionRepository()
        ..startFailure = const NavigationFailure(
          'You already have a trip in progress.',
          reason: NavigationFailureReason.activeSessionExists,
          activeSessionId: 9001,
        )
        ..others[9001] = ActiveTripDemoFixtures.createDemoSession();

      await tester.pumpWidget(
        buildPage(title: 'Real Trip', sessionRepository: sessions),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resumed your trip in progress.'), findsOneWidget);
      expect(find.text('Marble Mountains (Ngũ Hành Sơn)'), findsOneWidget);
    });

    testWidgets('production mode hides DEMO_ONLY controls', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        buildPage(
          title: 'Real Trip',
          sessionRepository: FakeSessionRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('DEMO_ONLY Controls'), findsNothing);
      expect(find.byIcon(Icons.build_circle_outlined), findsNothing);
    });

    testWidgets('demo mode shows the DEMO_ONLY controls and fixture title', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(buildPage(isDemoMode: true));
      await tester.pumpAndSettle();

      expect(find.text('Đà Nẵng Day Trip'), findsOneWidget);
      await tester.tap(find.byTooltip('DEMO_ONLY Controls'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO_ONLY Test Controls'), findsOneWidget);
    });

    testWidgets('loads the itinerary title without fabricating demo titles', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final repo = _FakeItineraryRepository(
        detail: _detail(title: 'Hanoi Heritage Tour'),
      );

      await tester.pumpWidget(
        buildPage(repository: repo, sessionRepository: FakeSessionRepository()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đà Nẵng Day Trip'), findsNothing);
      expect(find.text('Hanoi Heritage Tour'), findsOneWidget);
    });

    testWidgets('shows loading while metadata is being retrieved', (
      tester,
    ) async {
      usePhoneSurface(tester);
      final completer = Completer<ItineraryDetail>();

      await tester.pumpWidget(
        buildPage(
          repository: _FakeItineraryRepository(completer: completer),
          sessionRepository: FakeSessionRepository(),
        ),
      );
      await tester.pump();

      expect(find.text('Loading trip...'), findsOneWidget);

      completer.complete(_detail(title: 'Saigon Explorer'));
      await tester.pumpAndSettle();
      expect(find.text('Saigon Explorer'), findsOneWidget);
    });

    testWidgets('shows an error when metadata retrieval fails', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        buildPage(repository: _FakeItineraryRepository(shouldThrow: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unable to load trip'), findsOneWidget);
      expect(find.text('Trip information unavailable.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Go back'), findsOneWidget);
    });
  });

  group('ActiveTripPage UC-14/UC-15 demo', () {
    testWidgets('an open alerts sheet shows alerts received afterwards', (
      tester,
    ) async {
      useWideSurface(tester);
      final cubit = ActiveTripCubit(
        itineraryId: 101,
        sessionRepository: DemoNavigationSessionRepository(),
        initialAlerts: ActiveTripDemoFixtures.createSampleAlerts(),
        isDemoMode: true,
      );
      await cubit.start();

      await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Trip alerts log'));
      await tester.pumpAndSettle();

      expect(find.text('Live weather update'), findsNothing);
      cubit.addAlert(
        TripAlert(
          id: 'live-alert',
          title: 'Live weather update',
          description: 'Heavy rain is approaching the next stop.',
          severity: AlertSeverity.warning,
          type: TripAlertType.weather,
          affectedStopName: 'Next stop',
          timestamp: DateTime(2026, 10, 29),
        ),
      );
      expect(cubit.state.alerts.first.id, 'live-alert');
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(TripAlertsSheet),
          matching: find.text('Live weather update'),
        ),
        findsOneWidget,
      );
      await cubit.close();
    });

    testWidgets('renders the alert banner for an undismissed alert', (
      tester,
    ) async {
      useWideSurface(tester);
      final cubit = ActiveTripCubit(
        itineraryId: 101,
        sessionRepository: DemoNavigationSessionRepository(),
        initialAlerts: ActiveTripDemoFixtures.createSampleAlerts(),
        isDemoMode: true,
      );
      await cubit.start();

      await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();

      expect(find.byType(TripAlertBanner), findsOneWidget);
      expect(find.textContaining('Severe weather warning'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('accepting the reroute proposal bumps the version', (
      tester,
    ) async {
      useWideSurface(tester);
      final cubit = await startedDemoCubit();
      await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();

      cubit.openRerouteProposal();
      await tester.pumpAndSettle();
      expect(find.byType(RerouteProposalSheet), findsOneWidget);

      await tester.tap(find.text('Accept Re-routing'));
      await tester.pumpAndSettle();

      expect(find.byType(RerouteProposalSheet), findsNothing);
      expect(cubit.state.itineraryVersion, 2);
      await cubit.close();
    });

    testWidgets('declining keeps the version', (tester) async {
      useWideSurface(tester);
      final cubit = await startedDemoCubit();
      await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();

      cubit.openRerouteProposal();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep Current Route'));
      await tester.pumpAndSettle();

      expect(find.byType(RerouteProposalSheet), findsNothing);
      expect(cubit.state.itineraryVersion, 1);
      await cubit.close();
    });

    testWidgets('closing or dismissing the sheet keeps the proposal pending', (
      tester,
    ) async {
      useWideSurface(tester);
      final cubit = await startedDemoCubit();
      await tester.pumpWidget(buildPage(cubit: cubit, isDemoMode: true));
      await tester.pumpAndSettle();

      cubit.openRerouteProposal();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close without changing plan'));
      await tester.pumpAndSettle();

      expect(find.byType(RerouteProposalSheet), findsNothing);
      expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.pending);

      cubit.openRerouteProposal();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(RerouteProposalSheet))).pop();
      await tester.pumpAndSettle();

      expect(cubit.state.isRerouteSheetVisible, isFalse);
      expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.pending);

      cubit.openRerouteProposal();
      await tester.pumpAndSettle();
      expect(find.byType(RerouteProposalSheet), findsOneWidget);
      await cubit.close();
    });
  });
}

ItineraryDetail _detail({required String title}) => ItineraryDetail(
  itineraryId: 101,
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

final class _FakeItineraryRepository implements ItineraryRepository {
  _FakeItineraryRepository({
    this.detail,
    this.completer,
    this.shouldThrow = false,
  });

  final ItineraryDetail? detail;
  final Completer<ItineraryDetail>? completer;
  final bool shouldThrow;

  @override
  Future<ItineraryDetail> getById(int itineraryId) async {
    if (shouldThrow) throw Exception('Server unreachable');
    if (completer != null) return completer!.future;
    return detail ?? _detail(title: 'Sample Trip');
  }

  @override
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> accept(int itineraryId) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
  }) => throw UnimplementedError();
}
