import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/recommendation_feedback_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/navigation_location_tracker.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/demo_navigation_session_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/active_trip_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/navigation_map_canvas.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/reroute_proposal_sheet.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_alert_banner.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/trip_alerts_sheet.dart';

import '../../../../support/trip_alert_test_data.dart';
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
    for (final (bookingId, expected) in [
      (42, 'notice-42'),
      (null, 'history'),
    ]) {
      testWidgets('an emergency stop leads to $expected', (tester) async {
        usePhoneSurface(tester);
        final repository = FakeSessionRepository();
        final cubit = ActiveTripCubit(
          itineraryId: 101,
          itineraryTitle: 'Trip',
          sessionRepository: repository,
          locationTracker: FakeLocationTracker(),
          idempotencyKey: 'start-key',
        );
        addTearDown(cubit.close);
        await cubit.start();
        final running = cubit.state.session!;
        repository.others[running.sessionId] = NavigationSession(
          sessionId: running.sessionId,
          itineraryId: running.itineraryId,
          itineraryVersion: running.itineraryVersion,
          bookingId: bookingId,
          state: NavigationSessionState.interrupted,
          completionReason: null,
          startedAt: running.startedAt,
          expiresAt: running.expiresAt,
          endedAt: running.startedAt,
          exploringItemId: null,
          nextItemId: null,
          items: running.items,
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => ActiveTripPage(
                itineraryId: 101,
                cubit: cubit,
                useMapbox: false,
              ),
            ),
            GoRoute(
              path: AppRoutes.tripHistory,
              builder: (_, _) => const Text('history'),
            ),
            GoRoute(
              path: AppRoutes.travelerEmergencyPattern,
              builder: (_, state) =>
                  Text('notice-${state.pathParameters.values.single}'),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();

        await cubit.refreshSession();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Android Back must not leave the Traveler without the safety notice.
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Tour đã dừng vì an toàn'), findsOneWidget);

        await tester.tap(find.text('Xem thông báo an toàn'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(expected), findsOneWidget);
      });
    }

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

  group('ActiveTripPage UC-14/UC-15 alert and reroute UI', () {
    testWidgets('an open alerts sheet shows alerts received afterwards', (
      tester,
    ) async {
      useWideSurface(tester);
      final cubit = ActiveTripCubit(
        itineraryId: 101,
        sessionRepository: DemoNavigationSessionRepository(),
        initialAlerts: TripAlertTestData.sampleAlerts(),
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
        initialAlerts: TripAlertTestData.sampleAlerts(),
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

      cubit.openRerouteProposal(TripAlertTestData.sampleRerouteProposal());
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

      cubit.openRerouteProposal(TripAlertTestData.sampleRerouteProposal());
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

      cubit.openRerouteProposal(TripAlertTestData.sampleRerouteProposal());
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

  group('ActiveTripPage completion feedback', () {
    const marble = 'Marble Mountains (Ngũ Hành Sơn)';
    const chamMuseum = 'Bảo tàng Điêu khắc Chăm';
    final dialog = find.byType(AlertDialog);
    Finder inDialog(Finder finder) =>
        find.descendant(of: dialog, matching: finder);
    List<String?> snackBarTexts(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(SnackBar),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .toList();

    /// The trip page pushed over a home route, as in the app, so that
    /// "Back to Home" has somewhere to go.
    Future<void> pumpOverHome(
      WidgetTester tester,
      ActiveTripCubit cubit, {
      RecommendationFeedbackRepository? feedback,
    }) async {
      usePhoneSurface(tester);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('home screen'))),
      );
      unawaited(
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(
                builder: (_) => ActiveTripPage(
                  itineraryId: 101,
                  cubit: cubit,
                  feedbackRepository: feedback,
                  useMapbox: false,
                  isDemoMode: true,
                ),
              ),
            ),
      );
      await tester.pumpAndSettle();
    }

    /// Reaches the Marble Mountains (POI 11) and the Cham museum (POI 13),
    /// skips the restaurant in between and ends the trip with two stops left.
    Future<void> finishWithTwoReachedStops(
      WidgetTester tester,
      ActiveTripCubit cubit,
    ) async {
      await cubit.reachItem(1001);
      await cubit.depart();
      await cubit.skipItem(1002);
      await cubit.reachItem(1003);
      await cubit.finish();
      await tester.pumpAndSettle();
    }

    testWidgets('asks about the reached stops only', (tester) async {
      final cubit = await startedDemoCubit();
      await pumpOverHome(tester, cubit, feedback: _FakeFeedbackRepository());

      await finishWithTwoReachedStops(tester, cubit);

      expect(find.text('Navigation ended'), findsOneWidget);
      expect(
        inDialog(find.textContaining('You reached 2 of 5 stops')),
        findsOneWidget,
      );
      expect(
        inDialog(find.text('How were the stops? (optional)')),
        findsOneWidget,
      );
      expect(inDialog(find.text(marble)), findsOneWidget);
      expect(inDialog(find.text(chamMuseum)), findsOneWidget);
      // Skipped and never-reached stops are not asked about.
      expect(inDialog(find.text('Cơm Gà Bà Buội')), findsNothing);
      expect(inDialog(find.text('Chợ Hàn (Han Market)')), findsNothing);
      expect(find.byTooltip('Like $marble'), findsOneWidget);
      expect(find.byTooltip('Dislike $marble'), findsOneWidget);
      expect(inDialog(find.byIcon(Icons.thumb_up_outlined)), findsNWidgets(2));
      expect(
        inDialog(find.byIcon(Icons.thumb_down_outlined)),
        findsNWidgets(2),
      );
    });

    testWidgets('sends the chosen thumbs when the traveler leaves', (
      tester,
    ) async {
      final feedback = _FakeFeedbackRepository();
      final cubit = await startedDemoCubit();
      await pumpOverHome(tester, cubit, feedback: feedback);
      await finishWithTwoReachedStops(tester, cubit);

      await tester.tap(find.byTooltip('Like $marble'));
      // Changing one's mind keeps the last answer only.
      await tester.tap(find.byTooltip('Like $chamMuseum'));
      await tester.pump();
      await tester.tap(find.byTooltip('Dislike $chamMuseum'));
      await tester.pump();

      expect(inDialog(find.byIcon(Icons.thumb_up)), findsOneWidget);
      expect(inDialog(find.byIcon(Icons.thumb_down)), findsOneWidget);
      // Nothing is sent while the dialog is still open.
      expect(feedback.sent, isEmpty);

      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      expect(find.text('home screen'), findsOneWidget);
      expect(
        feedback.sent.map(
          (event) => (event.itineraryId, event.poiId, event.liked),
        ),
        [(101, 11, true), (101, 13, false)],
      );
      final eventIds = feedback.sent.map((event) => event.clientEventId);
      expect(eventIds.toSet(), hasLength(2));
      expect(
        eventIds,
        everyElement(
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        ),
      );
    });

    testWidgets('tapping the chosen thumb again clears the answer', (
      tester,
    ) async {
      final feedback = _FakeFeedbackRepository();
      final cubit = await startedDemoCubit();
      await pumpOverHome(tester, cubit, feedback: feedback);
      await finishWithTwoReachedStops(tester, cubit);

      await tester.tap(find.byTooltip('Like $marble'));
      await tester.pump();
      expect(inDialog(find.byIcon(Icons.thumb_up)), findsOneWidget);

      await tester.tap(find.byTooltip('Like $marble'));
      await tester.pump();
      expect(inDialog(find.byIcon(Icons.thumb_up)), findsNothing);

      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      expect(find.text('home screen'), findsOneWidget);
      expect(feedback.sent, isEmpty);
    });

    testWidgets('leaving without an answer sends nothing', (tester) async {
      final feedback = _FakeFeedbackRepository();
      final cubit = await startedDemoCubit();
      await pumpOverHome(tester, cubit, feedback: feedback);
      await finishWithTwoReachedStops(tester, cubit);

      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      expect(find.text('home screen'), findsOneWidget);
      expect(feedback.sent, isEmpty);
    });

    testWidgets('still goes home when sending fails', (tester) async {
      final feedback = _FakeFeedbackRepository()
        ..failure = const NetworkFailure();
      final cubit = await startedDemoCubit();
      await pumpOverHome(tester, cubit, feedback: feedback);
      await finishWithTwoReachedStops(tester, cubit);

      await tester.tap(find.byTooltip('Like $marble'));
      await tester.tap(find.byTooltip('Dislike $chamMuseum'));
      await tester.pump();
      // The trip's own "Arrived at ..." message may still be showing.
      final messagesBefore = snackBarTexts(tester);
      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      expect(find.text('home screen'), findsOneWidget);
      // Both were tried; neither failure reached the traveler.
      expect(feedback.sent, hasLength(2));
      expect(snackBarTexts(tester), messagesBefore);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not wait for a send that never answers', (tester) async {
      final feedback = _FakeFeedbackRepository()..neverAnswers = true;
      final cubit = await startedDemoCubit();
      await pumpOverHome(tester, cubit, feedback: feedback);
      await finishWithTwoReachedStops(tester, cubit);

      await tester.tap(find.byTooltip('Like $marble'));
      await tester.tap(find.byTooltip('Like $chamMuseum'));
      await tester.pump();
      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      expect(find.text('home screen'), findsOneWidget);
      // The second answer is not held back by the first.
      expect(feedback.sent, hasLength(2));
    });

    testWidgets('does not ask when feedback cannot be sent', (tester) async {
      final cubit = await startedDemoCubit();
      await pumpOverHome(tester, cubit);

      await finishWithTwoReachedStops(tester, cubit);

      expect(
        inDialog(find.textContaining('You reached 2 of 5 stops')),
        findsOneWidget,
      );
      expect(find.text('How were the stops? (optional)'), findsNothing);
      expect(inDialog(find.byIcon(Icons.thumb_up_outlined)), findsNothing);
      expect(find.text('Back to Home'), findsOneWidget);
    });

    testWidgets('does not ask when no stop was reached', (tester) async {
      final cubit = await startedDemoCubit();
      await pumpOverHome(tester, cubit, feedback: _FakeFeedbackRepository());

      await cubit.finish();
      await tester.pumpAndSettle();

      expect(
        inDialog(find.textContaining('You reached 0 of 5 stops')),
        findsOneWidget,
      );
      expect(find.text('How were the stops? (optional)'), findsNothing);
    });

    testWidgets('a long list of reached stops scrolls inside the dialog', (
      tester,
    ) async {
      final feedback = _FakeFeedbackRepository();
      final template = ActiveTripDemoFixtures.createDemoSession();
      final session = template.copyWith(
        items: [
          for (var number = 1; number <= 30; number++)
            NavigationSessionItem(
              itemId: 2000 + number,
              sequenceNo: number,
              poiId: 500 + number,
              poiName: 'Stop $number',
              latitude: 16,
              longitude: 108,
              plannedArrival: template.startedAt,
              plannedDeparture: template.startedAt,
              isMandatory: false,
              status: NavigationItemStatus.reached,
              reachedAt: template.startedAt,
              skippedAt: null,
            ),
        ],
      );
      final cubit = ActiveTripCubit(
        itineraryId: 101,
        itineraryTitle: 'Long trip',
        sessionRepository: DemoNavigationSessionRepository(
          initialSession: session,
        ),
        initialAlerts: const [],
        isDemoMode: true,
      );
      await cubit.start();
      await pumpOverHome(tester, cubit, feedback: feedback);

      await cubit.finish();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Trip Completed!'), findsOneWidget);
      // The button stays on screen; the last stop is reached by scrolling.
      expect(find.text('Back to Home').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Dislike Stop 30').hitTestable(), findsNothing);

      await tester.ensureVisible(find.byTooltip('Dislike Stop 30'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Dislike Stop 30'));
      await tester.pump();
      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      expect(find.text('home screen'), findsOneWidget);
      expect(
        feedback.sent.map(
          (event) => (event.itineraryId, event.poiId, event.liked),
        ),
        [(101, 530, false)],
      );
    });
  });
}

final class _FakeFeedbackRepository
    implements RecommendationFeedbackRepository {
  final sent =
      <({String clientEventId, int itineraryId, int poiId, bool liked})>[];
  Failure? failure;
  bool neverAnswers = false;

  @override
  Future<void> sendStopFeedback({
    required String clientEventId,
    required int itineraryId,
    required int poiId,
    required bool liked,
  }) async {
    sent.add((
      clientEventId: clientEventId,
      itineraryId: itineraryId,
      poiId: poiId,
      liked: liked,
    ));
    if (neverAnswers) await Completer<void>().future;
    if (failure case final failure?) throw failure;
  }
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
    Map<int, StopRemovalReason> removalReasons = const {},
  }) => throw UnimplementedError();
}
