import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/weather_advisory.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/navigation_session_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/trip_alert_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/navigation_location_tracker.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/demo_navigation_session_repository.dart';

void main() {
  late DateTime now;
  late FakeSessionRepository repository;
  late FakeLocationTracker tracker;

  setUp(() {
    now = DateTime.utc(2026, 10, 20, 2);
    repository = FakeSessionRepository();
    tracker = FakeLocationTracker();
  });

  tearDown(() => tracker.dispose());

  ActiveTripCubit createCubit({
    RouteDirectionsRepository? directions,
    NavigationLocationTracker? locationTracker,
    NetworkInfo? networkInfo,
    TripAlertRepository? alertRepository,
  }) => ActiveTripCubit(
    itineraryId: 101,
    itineraryTitle: 'Đà Nẵng City Explorer',
    sessionRepository: repository,
    locationTracker: locationTracker ?? tracker,
    directionsRepository: directions,
    clock: () => now,
    idempotencyKey: 'start-key',
    networkInfo: networkInfo,
    alertRepository: alertRepository,
  );

  NavigationPosition at(NavigationSessionItem item, {double offset = 0}) =>
      NavigationPosition(
        coordinate: NavigationCoordinate(
          latitude: item.latitude + offset,
          longitude: item.longitude,
        ),
        timestamp: now,
        accuracyMeters: 5,
      );

  group('Starting navigation', () {
    test(
      'starts a session, targets the suggested stop, and tracks GPS',
      () async {
        final cubit = createCubit();

        await cubit.start();
        await pumpEventQueue();

        expect(repository.calls, ['start:101:start-key']);
        expect(cubit.state.loadStatus, ActiveTripLoadStatus.ready);
        expect(cubit.state.session?.sessionId, 9001);
        expect(cubit.state.targetItemId, 1001);
        expect(
          cubit.state.status,
          ActiveTripStatus.navigationAcquiringPosition,
        );
        expect(tracker.hasListener, isTrue);

        final target = cubit.state.targetItem!;
        tracker.emit(at(target, offset: 0.01));
        await pumpEventQueue();

        expect(cubit.state.status, ActiveTripStatus.navigationActive);
        expect(cubit.state.distanceToTargetMeters, closeTo(1112, 5));
        await cubit.close();
      },
    );

    test('resumes the open session of the same itinerary', () async {
      repository
        ..startFailure = const NavigationFailure(
          'You already have a trip in progress.',
          reason: NavigationFailureReason.activeSessionExists,
          activeSessionId: 9001,
        )
        ..others[9001] = ActiveTripDemoFixtures.createDemoSession();
      final cubit = createCubit();

      await cubit.start();

      expect(repository.calls, ['start:101:start-key', 'get:9001']);
      expect(cubit.state.loadStatus, ActiveTripLoadStatus.ready);
      expect(cubit.state.feedback?.message, 'Resumed your trip in progress.');
      await cubit.close();
    });

    test(
      'offers to end the open session of another itinerary before starting',
      () async {
        repository
          ..startFailure = const NavigationFailure(
            'You already have a trip in progress.',
            reason: NavigationFailureReason.activeSessionExists,
            activeSessionId: 77,
          )
          ..others[77] = ActiveTripDemoFixtures.createDemoSession(
            itineraryId: 55,
            sessionId: 77,
          );
        final cubit = createCubit();

        await cubit.start();

        expect(cubit.state.loadStatus, ActiveTripLoadStatus.conflict);
        expect(cubit.state.conflictSession?.itineraryId, 55);

        await cubit.endConflictingSessionAndStart();

        expect(repository.calls, [
          'start:101:start-key',
          'get:77',
          'complete:77',
          'start:101:start-key',
        ]);
        expect(cubit.state.loadStatus, ActiveTripLoadStatus.ready);
        expect(cubit.state.conflictSession, isNull);
        await cubit.close();
      },
    );

    test(
      'an inaccessible open session can still be ended before starting',
      () async {
        repository
          ..startFailure = const NavigationFailure(
            'You already have a trip in progress.',
            reason: NavigationFailureReason.activeSessionExists,
            activeSessionId: 88,
          )
          ..getFailures[88] = const NavigationFailure(
            'You no longer have access to this trip.',
            reason: NavigationFailureReason.accessDenied,
          );
        final cubit = createCubit();

        await cubit.start();

        expect(cubit.state.loadStatus, ActiveTripLoadStatus.conflict);
        expect(cubit.state.conflictSession, isNull);
        expect(cubit.state.conflictSessionId, 88);

        await cubit.endConflictingSessionAndStart();

        expect(repository.calls, contains('complete:88'));
        expect(cubit.state.loadStatus, ActiveTripLoadStatus.ready);
        await cubit.close();
      },
    );

    test('surfaces start errors and can retry with the same key', () async {
      repository.startFailure = const NavigationFailure(
        'This trip can only be navigated during its scheduled time.',
        reason: NavigationFailureReason.outsideTripWindow,
      );
      final cubit = createCubit();

      await cubit.start();

      expect(cubit.state.loadStatus, ActiveTripLoadStatus.failed);
      expect(
        cubit.state.loadErrorMessage,
        'This trip can only be navigated during its scheduled time.',
      );

      await cubit.start();
      expect(cubit.state.loadStatus, ActiveTripLoadStatus.ready);
      expect(repository.calls, ['start:101:start-key', 'start:101:start-key']);
      await cubit.close();
    });

    test('reports denied location permission without tracking', () async {
      tracker.access = NavigationLocationAccess.denied;
      final cubit = createCubit();

      await cubit.start();
      await pumpEventQueue();

      expect(cubit.state.status, ActiveTripStatus.navigationPermissionDenied);
      expect(tracker.hasListener, isFalse);

      tracker.access = NavigationLocationAccess.granted;
      await cubit.retryLocation();
      expect(tracker.hasListener, isTrue);
      await cubit.close();
    });
  });

  group('Arrival', () {
    test(
      'GPS dwell proposes arrival; confirming reaches with the detection time',
      () async {
        final cubit = createCubit();
        await cubit.start();
        await pumpEventQueue();
        final target = cubit.state.targetItem!;

        cubit.updatePosition(at(target));
        expect(cubit.state.arrivalPromptItemId, isNull);

        now = now.add(const Duration(seconds: 25));
        final detectedAt = now;
        cubit.updatePosition(at(target));
        expect(cubit.state.arrivalPromptItemId, target.itemId);

        now = now.add(const Duration(minutes: 1));
        await cubit.confirmArrival();

        expect(repository.reachTimes, [detectedAt]);
        expect(cubit.state.arrivalPromptItemId, isNull);
        expect(cubit.state.isExploring, isTrue);
        expect(cubit.state.exploringItem?.itemId, target.itemId);
        expect(cubit.state.targetItemId, isNull);
        expect(cubit.state.feedback?.message, 'Arrived at ${target.poiName}.');
        await cubit.close();
      },
    );

    test('"Not yet" suppresses the prompt while the Traveler stays', () async {
      final cubit = createCubit();
      await cubit.start();
      final target = cubit.state.targetItem!;

      cubit.updatePosition(at(target));
      now = now.add(const Duration(seconds: 25));
      cubit.updatePosition(at(target));
      expect(cubit.state.arrivalPromptItemId, target.itemId);

      cubit.dismissArrivalPrompt();
      now = now.add(const Duration(minutes: 5));
      cubit.updatePosition(at(target));

      expect(cubit.state.arrivalPromptItemId, isNull);
      expect(repository.reachTimes, isEmpty);
      await cubit.close();
    });

    test(
      'nearby stops are not proposed while exploring, only after departing',
      () async {
        final cubit = createCubit();
        await cubit.start();
        final first = cubit.state.targetItem!;
        await cubit.reachItem(first.itemId);
        final nearby = cubit.state.session!.itemById(1002)!;

        cubit.updatePosition(at(nearby));
        now = now.add(const Duration(seconds: 25));
        cubit.updatePosition(at(nearby));
        expect(cubit.state.isExploring, isTrue);
        expect(cubit.state.arrivalPromptItemId, isNull);

        await cubit.depart();
        cubit.updatePosition(at(nearby));
        expect(cubit.state.arrivalPromptItemId, isNull);
        now = now.add(const Duration(seconds: 25));
        cubit.updatePosition(at(nearby));
        expect(cubit.state.arrivalPromptItemId, nearby.itemId);
        await cubit.close();
      },
    );

    test('manual arrival reaches any reachable stop', () async {
      final cubit = createCubit();
      await cubit.start();

      await cubit.reachItem(1003);

      expect(repository.reachTimes, [now]);
      expect(cubit.state.exploringItem?.itemId, 1003);
      expect(cubit.state.session?.nextItemId, 1001);
      await cubit.close();
    });
  });

  group('Progress', () {
    test('depart returns to Navigating and targets the next stop', () async {
      final cubit = createCubit();
      await cubit.start();
      await cubit.reachItem(1001);

      await cubit.depart();

      expect(cubit.state.isExploring, isFalse);
      expect(cubit.state.targetItemId, 1002);
      await cubit.close();
    });

    test('selecting a stop while exploring departs toward it', () async {
      final cubit = createCubit();
      await cubit.start();
      await cubit.reachItem(1001);

      await cubit.selectTarget(1004);

      expect(repository.calls.last, 'depart');
      expect(cubit.state.isExploring, isFalse);
      expect(cubit.state.targetItemId, 1004);
      await cubit.close();
    });

    test('skipping the target keeps the session state and moves on', () async {
      final cubit = createCubit();
      await cubit.start();

      await cubit.skipItem(1001);

      expect(cubit.state.session?.state, NavigationSessionState.navigating);
      expect(
        cubit.state.session?.itemById(1001)?.status,
        NavigationItemStatus.skipped,
      );
      expect(cubit.state.targetItemId, 1002);
      await cubit.close();
    });

    test('skipped stops are never targeted automatically', () async {
      final cubit = createCubit();
      await cubit.start();
      for (final id in [1001, 1002, 1003, 1004]) {
        await cubit.reachItem(id);
      }
      await cubit.depart();
      expect(cubit.state.targetItemId, 1005);

      await cubit.skipItem(1005);

      expect(cubit.state.targetItemId, isNull);
      expect(cubit.state.hasPendingItems, isFalse);

      await cubit.selectTarget(1005);
      expect(cubit.state.targetItemId, 1005);
      await cubit.close();
    });

    test('finishing ends navigation and ignores later GPS fixes', () async {
      final cubit = createCubit();
      await cubit.start();
      await pumpEventQueue();
      final target = cubit.state.targetItem!;

      await cubit.finish();
      await pumpEventQueue();

      expect(cubit.state.isTerminal, isTrue);
      expect(
        cubit.state.session?.completionReason,
        NavigationCompletionReason.travelerStopped,
      );
      expect(cubit.state.targetItemId, isNull);
      expect(tracker.hasListener, isFalse);

      cubit.updatePosition(at(target));
      expect(cubit.state.currentLatitude, isNull);
      await cubit.close();
    });

    test(
      'a session completed elsewhere (e.g. expired) is reloaded and shown as ended',
      () async {
        final cubit = createCubit();
        await cubit.start();
        await repository.demo.complete(9001);
        repository.nextMutationFailure = const NavigationFailure(
          'This navigation session has already ended.',
          reason: NavigationFailureReason.sessionCompleted,
        );

        await cubit.reachItem(1001);

        expect(repository.calls.last, 'get:9001');
        expect(cubit.state.isTerminal, isTrue);
        expect(cubit.state.feedback?.isError, isTrue);
        await cubit.close();
      },
    );

    test('network errors keep the session and report the failure', () async {
      final cubit = createCubit();
      await cubit.start();
      repository.nextMutationFailure = const NetworkFailure();

      await cubit.skipItem(1001);

      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.feedback?.message, const NetworkFailure().message);
      expect(cubit.state.targetItemId, 1001);
      await cubit.close();
    });
  });

  group('Arrival prompt lifecycle', () {
    test(
      'a pending question is withdrawn once the Traveler walks away',
      () async {
        final cubit = createCubit();
        await cubit.start();
        final target = cubit.state.targetItem!;
        cubit.updatePosition(at(target));
        now = now.add(const Duration(seconds: 25));
        cubit.updatePosition(at(target));
        expect(cubit.state.arrivalPromptItemId, target.itemId);

        // About 220 m north: well beyond 1.5 × the 50 m arrival radius.
        cubit.updatePosition(at(target, offset: 0.002));

        expect(cubit.state.arrivalPromptItemId, isNull);
        expect(repository.reachTimes, isEmpty);
        await cubit.close();
      },
    );

    test('no question is raised while another dialog is open', () async {
      final cubit = createCubit();
      await cubit.start();
      final target = cubit.state.targetItem!;

      cubit.pauseArrivalPrompts();
      cubit.updatePosition(at(target));
      now = now.add(const Duration(seconds: 25));
      cubit.updatePosition(at(target));
      expect(cubit.state.arrivalPromptItemId, isNull);

      cubit.resumeArrivalPrompts();
      cubit.updatePosition(at(target));
      expect(cubit.state.arrivalPromptItemId, target.itemId);
      await cubit.close();
    });
  });

  group('Failure handling', () {
    test('a network failure can be retried with the same action', () async {
      final cubit = createCubit();
      await cubit.start();
      repository.nextMutationFailure = const NetworkFailure();

      await cubit.skipItem(1001);
      expect(cubit.state.feedback?.isError, isTrue);
      expect(cubit.state.feedback?.canRetry, isTrue);

      await cubit.retryLastAction();

      expect(
        repository.calls.where((call) => call == 'skip:1001'),
        hasLength(2),
      );
      expect(
        cubit.state.session?.itemById(1001)?.status,
        NavigationItemStatus.skipped,
      );
      await cubit.close();
    });

    test('a business rejection is not offered for retry', () async {
      final cubit = createCubit();
      await cubit.start();
      repository.nextMutationFailure = const NavigationFailure(
        'This stop is not part of the navigation session.',
        reason: NavigationFailureReason.itemNotNavigable,
      );

      await cubit.skipItem(1001);

      expect(cubit.state.feedback?.isError, isTrue);
      expect(cubit.state.feedback?.canRetry, isFalse);
      await cubit.close();
    });

    test('offline actions fail fast without calling the server', () async {
      final network = FakeNetworkInfo(online: false);
      final cubit = createCubit(networkInfo: network);
      await cubit.start();
      await pumpEventQueue();
      expect(cubit.state.isOnline, isFalse);

      await cubit.skipItem(1001);

      expect(repository.calls, isNot(contains('skip:1001')));
      expect(cubit.state.feedback?.message, ActiveTripCubit.offlineMessage);
      expect(cubit.state.feedback?.canRetry, isTrue);

      network.set(true);
      await pumpEventQueue();
      expect(cubit.state.isOnline, isTrue);
      await cubit.retryLastAction();
      expect(repository.calls, contains('skip:1001'));
      await cubit.close();
      await network.dispose();
    });

    test('a start outside the trip window cannot be retried', () async {
      repository.startFailure = const NavigationFailure(
        'This trip can only be navigated during its scheduled time.',
        reason: NavigationFailureReason.outsideTripWindow,
      );
      final cubit = createCubit();

      await cubit.start();

      expect(cubit.state.loadStatus, ActiveTripLoadStatus.failed);
      expect(cubit.state.canRetryLoad, isFalse);
      await cubit.close();
    });
  });

  group('Guidance', () {
    test('fetches a route to the target and shows the next maneuver', () async {
      final directions = FakeDirections();
      final cubit = createCubit(directions: directions);
      await cubit.start();
      final target = cubit.state.targetItem!;

      cubit.updatePosition(at(target, offset: -0.009));
      await pumpEventQueue();

      expect(directions.requests, 1);
      expect(cubit.state.route, isNotNull);
      expect(cubit.state.isGuidanceAvailable, isTrue);
      expect(cubit.state.currentManeuver?.instruction, 'Arrive at the stop');
      expect(cubit.state.remainingDurationSeconds, isNotNull);
      await cubit.close();
    });

    test('routes with the mode the itinerary was planned with', () async {
      repository = FakeSessionRepository(transportMode: TransportMode.walking);
      final directions = FakeDirections();
      final cubit = createCubit(directions: directions);
      await cubit.start();
      final target = cubit.state.targetItem!;

      cubit.updatePosition(at(target, offset: -0.009));
      await pumpEventQueue();

      expect(cubit.state.session?.transportMode, TransportMode.walking);
      expect(directions.requestedModes, [TransportMode.walking]);
      await cubit.close();
    });

    test('routes with the mode the traveler chose for the leg', () async {
      final trip = ActiveTripDemoFixtures.createDemoSession(
        transportMode: TransportMode.motorbike,
      );
      repository = FakeSessionRepository(
        initialSession: trip.copyWith(
          items: [
            for (final item in trip.items)
              item.copyWith(transportModeFromPrevious: TransportMode.walking),
          ],
        ),
      );
      final directions = FakeDirections();
      final cubit = createCubit(directions: directions);
      await cubit.start();
      final target = cubit.state.targetItem!;

      cubit.updatePosition(at(target, offset: -0.009));
      await pumpEventQueue();

      expect(cubit.state.session?.transportMode, TransportMode.motorbike);
      expect(directions.requestedModes, [TransportMode.walking]);
      await cubit.close();
    });

    test('falls back to the trip mode when the leg mode is unknown', () async {
      repository = FakeSessionRepository(
        transportMode: TransportMode.motorbike,
      );
      final directions = FakeDirections();
      final cubit = createCubit(directions: directions);
      await cubit.start();
      final target = cubit.state.targetItem!;

      cubit.updatePosition(at(target, offset: -0.009));
      await pumpEventQueue();

      expect(target.transportModeFromPrevious, isNull);
      expect(directions.requestedModes, [TransportMode.motorbike]);
      await cubit.close();
    });

    test(
      'three far fixes mark off-route and request a new route after the cooldown',
      () async {
        final directions = FakeDirections();
        final alerts = FakeAlertRepository()..networkFailuresRemaining = 1;
        final cubit = createCubit(
          directions: directions,
          alertRepository: alerts,
        );
        await cubit.start();
        final target = cubit.state.targetItem!;
        cubit.updatePosition(at(target, offset: -0.009));
        await pumpEventQueue();

        final far = NavigationPosition(
          coordinate: NavigationCoordinate(
            latitude: target.latitude - 0.005,
            longitude: target.longitude + 0.01,
          ),
          timestamp: now,
          accuracyMeters: 5,
        );
        for (var i = 0; i < 3; i++) {
          cubit.updatePosition(far);
        }
        await pumpEventQueue();
        expect(
          cubit.state.status,
          ActiveTripStatus.navigationOffRouteDeviation,
        );
        expect(directions.requests, 1);
        expect(alerts.deviations, [target.itemId, target.itemId]);
        expect(alerts.deviationEventIds.toSet(), hasLength(1));

        now = now.add(ActiveTripCubit.routeRequestCooldown);
        cubit.updatePosition(far);
        await pumpEventQueue();

        expect(directions.requests, 2);
        expect(cubit.state.status, ActiveTripStatus.navigationActive);
        await cubit.close();
      },
    );

    test('failed route requests respect the cooldown', () async {
      final directions = FakeDirections()..failing = true;
      final cubit = createCubit(directions: directions);
      await cubit.start();
      final target = cubit.state.targetItem!;

      for (var i = 0; i < 5; i++) {
        cubit.updatePosition(at(target, offset: -0.009 + i * 0.0001));
        await pumpEventQueue();
      }
      expect(directions.requests, 1);
      expect(cubit.state.distanceToTargetMeters, isNotNull);

      now = now.add(ActiveTripCubit.routeRequestCooldown);
      cubit.updatePosition(at(target, offset: -0.008));
      await pumpEventQueue();
      expect(directions.requests, 2);
      await cubit.close();
    });

    test('without guidance the distance is a straight line', () async {
      final cubit = createCubit();
      await cubit.start();

      cubit.updatePosition(at(cubit.state.targetItem!, offset: 0.001));

      expect(cubit.state.isGuidanceAvailable, isFalse);
      expect(cubit.state.currentManeuver, isNull);
      expect(cubit.state.distanceToTargetMeters, closeTo(111, 2));
      await cubit.close();
    });
  });

  group('Demo mode', () {
    late ActiveTripCubit cubit;

    setUp(() async {
      cubit = ActiveTripCubit(
        itineraryId: 101,
        itineraryTitle: 'Đà Nẵng City Explorer',
        sessionRepository: DemoNavigationSessionRepository(),
        isDemoMode: true,
      );
      await cubit.start();
    });

    tearDown(() => cubit.close());

    test('loads the in-memory session with sample alerts', () {
      expect(cubit.state.status, ActiveTripStatus.navigationActive);
      expect(cubit.state.items.length, 5);
      expect(
        cubit.state.targetItem?.poiName,
        'Marble Mountains (Ngũ Hành Sơn)',
      );
      expect(cubit.state.alerts, isNotEmpty);
    });

    test('simulated arrival raises the confirmation prompt', () async {
      cubit.demoSimulateArrivalAtNextStop();
      expect(cubit.state.arrivalPromptItemId, 1001);

      await cubit.confirmArrival();
      expect(cubit.state.exploringItem?.itemId, 1001);
    });

    test('demo GPS simulations change the status', () {
      cubit.demoSimulatePermissionDenied();
      expect(cubit.state.status, ActiveTripStatus.navigationPermissionDenied);
      cubit.demoSimulateGpsLost();
      expect(
        cubit.state.status,
        ActiveTripStatus.navigationPositionUnavailable,
      );
      cubit.demoSimulateRouteDeviation();
      expect(cubit.state.status, ActiveTripStatus.navigationOffRouteDeviation);
      expect(
        cubit.state.alerts.any((a) => a.type == TripAlertType.deviation),
        isTrue,
      );
    });

    test('dismissing banner alert keeps alert in alerts history', () {
      final initialCount = cubit.state.alerts.length;
      final activeAlert = cubit.state.activeBannerAlert!;

      cubit.dismissBannerAlert(activeAlert.id);

      expect(cubit.state.activeBannerAlert, isNull);
      expect(cubit.state.alerts.length, initialCount);
      expect(
        cubit.state.alerts
            .firstWhere((a) => a.id == activeAlert.id)
            .isDismissedFromBanner,
        isTrue,
      );
    });

    test('re-routing acceptance bumps the version and applies the shelter', () {
      cubit.openRerouteProposal(
        ActiveTripDemoFixtures.createSampleRerouteProposal(),
      );
      cubit.acceptRerouteProposal();

      expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.accepted);
      expect(cubit.state.itineraryVersion, 2);
      expect(cubit.state.items[3].poiName, contains('Indoor Shelter'));

      cubit.openRerouteProposal();
      expect(cubit.state.isRerouteSheetVisible, isFalse);
      cubit.acceptRerouteProposal();
      expect(cubit.state.itineraryVersion, 2);
    });

    test('declined and expired proposals cannot be accepted later', () {
      cubit.openRerouteProposal(
        ActiveTripDemoFixtures.createSampleRerouteProposal(),
      );
      cubit.declineRerouteProposal();
      expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.declined);
      cubit.acceptRerouteProposal();
      expect(cubit.state.itineraryVersion, 1);

      cubit.openRerouteProposal(
        ActiveTripDemoFixtures.createSampleRerouteProposal(),
      );
      cubit.expireRerouteProposal();
      expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.expired);
      cubit.openRerouteProposal();
      expect(cubit.state.isRerouteSheetVisible, isFalse);
    });

    test('closeRerouteProposalSheet is idempotent when already closed', () {
      var emitted = false;
      final subscription = cubit.stream.listen((_) => emitted = true);

      cubit.closeRerouteProposalSheet();

      expect(emitted, isFalse);
      subscription.cancel();
    });

    test('a finished trip rejects reroute actions and new alerts', () async {
      cubit.openRerouteProposal(
        ActiveTripDemoFixtures.createSampleRerouteProposal(),
      );
      await cubit.finish();

      expect(cubit.state.isTerminal, isTrue);
      expect(cubit.state.isRerouteSheetVisible, isFalse);
      cubit.acceptRerouteProposal();
      expect(cubit.state.itineraryVersion, 1);

      final alertsBefore = cubit.state.alerts.length;
      cubit.addAlert(
        TripAlert(
          id: 'late-alert',
          title: 'Late alert',
          description: 'Should be ignored',
          severity: AlertSeverity.info,
          type: TripAlertType.delay,
          affectedStopName: 'Stop',
          timestamp: DateTime.now(),
        ),
      );
      expect(cubit.state.alerts.length, alertsBefore);
    });
  });

  group('Production / demo boundary', () {
    test('production cubit never invents fixtures or demo events', () async {
      final cubit = createCubit();
      await cubit.start();
      await pumpEventQueue();
      final statusBefore = cubit.state.status;

      expect(cubit.state.isDemoMode, isFalse);
      expect(cubit.state.alerts, isEmpty);
      cubit.demoSimulateArrivalAtNextStop();
      cubit.demoSimulateWeatherDisruption();
      cubit.demoSimulatePermissionDenied();
      cubit.openRerouteProposal();

      expect(cubit.state.arrivalPromptItemId, isNull);
      expect(cubit.state.alerts, isEmpty);
      expect(cubit.state.status, statusBefore);
      expect(cubit.state.activeRerouteProposal, isNull);
      await cubit.close();
    });
  });

  group('UC-14 server alerts', () {
    test('loads persisted alerts and advisories after session start', () async {
      final alerts = FakeAlertRepository();
      final cubit = createCubit(alertRepository: alerts);

      await cubit.start();
      await pumpEventQueue();

      expect(alerts.listCalls, [9001]);
      expect(cubit.state.alerts.single.id, '42');
      expect(cubit.state.activeBannerAlert?.id, '42');
      expect(cubit.state.activeWeatherAdvisory?.advisoryKey, 'rain:1001');
      expect(cubit.state.alertRefreshStatus, AlertRefreshStatus.success);
      await cubit.close();
    });

    test('acknowledges an alert and keeps read as terminal locally', () async {
      final alerts = FakeAlertRepository();
      final cubit = createCubit(alertRepository: alerts);
      await cubit.start();
      await pumpEventQueue();

      await cubit.acknowledgeAlert(alerts.persisted.single);

      expect(alerts.acknowledged, [42]);
      expect(cubit.state.alerts.single.isRead, isTrue);
      await cubit.close();
    });

    test('a slower refresh cannot overwrite a newer alert response', () async {
      final alerts = FakeAlertRepository();
      final cubit = createCubit(alertRepository: alerts);
      await cubit.start();
      await pumpEventQueue();
      final older = Completer<List<TripAlert>>();
      final newer = Completer<List<TripAlert>>();
      alerts.queuedAlertResponses.addAll([older, newer]);

      final firstRefresh = cubit.refreshAlerts();
      final secondRefresh = cubit.refreshAlerts();
      newer.complete([alerts.persisted.single.copyWith(isRead: true)]);
      await secondRefresh;
      older.complete([alerts.persisted.single.copyWith(isRead: false)]);
      await firstRefresh;

      expect(cubit.state.alerts.single.isRead, isTrue);
      await cubit.close();
    });
  });
}

final class FakeAlertRepository implements TripAlertRepository {
  final persisted = <TripAlert>[
    TripAlert(
      id: '42',
      title: 'Route deviation',
      description: 'You appear to be away from the planned route.',
      severity: AlertSeverity.warning,
      type: TripAlertType.deviation,
      affectedStopName: 'Museum',
      timestamp: DateTime.utc(2026, 10, 20, 2),
      affectedItemId: 1001,
    ),
  ];
  final List<int> listCalls = [];
  final List<int> acknowledged = [];
  final List<int> deviations = [];
  final List<String> deviationEventIds = [];
  final List<Completer<List<TripAlert>>> queuedAlertResponses = [];
  int networkFailuresRemaining = 0;

  @override
  Future<List<TripAlert>> listAlerts(int sessionId) async {
    listCalls.add(sessionId);
    if (queuedAlertResponses.isNotEmpty) {
      return queuedAlertResponses.removeAt(0).future;
    }
    return List.of(persisted);
  }

  @override
  Future<List<WeatherAdvisory>> listWeatherAdvisories(int sessionId) async => [
    WeatherAdvisory(
      advisoryKey: 'rain:1001',
      messageCode: 'trip_alert.weather_advisory',
      itemId: 1001,
      poiId: 1,
      poiName: 'Museum',
      plannedArrivalUtc: DateTime.utc(2026, 10, 20, 2),
      forecastAtUtc: DateTime.utc(2026, 10, 20, 2),
      rainMmPerHour: 4.5,
    ),
  ];

  @override
  Future<void> acknowledgeAlert({
    required int sessionId,
    required int incidentId,
  }) async => acknowledged.add(incidentId);

  @override
  Future<TripAlert> reportDeviation({
    required int sessionId,
    required String eventId,
    required DateTime observedAtUtc,
    required int targetItemId,
  }) async {
    deviations.add(targetItemId);
    deviationEventIds.add(eventId);
    if (networkFailuresRemaining > 0) {
      networkFailuresRemaining--;
      throw const NetworkFailure();
    }
    return persisted.single;
  }
}

/// Delegates to the in-memory demo repository and records calls; failures can
/// be injected for the next start or mutation.
final class FakeSessionRepository implements NavigationSessionRepository {
  FakeSessionRepository({
    TransportMode? transportMode,
    NavigationSession? initialSession,
  }) : demo = DemoNavigationSessionRepository(
         initialSession: initialSession,
         transportMode: transportMode,
       );

  final DemoNavigationSessionRepository demo;
  final Map<int, NavigationSession> others = {};
  final Map<int, Failure> getFailures = {};
  final List<String> calls = [];
  final List<DateTime> reachTimes = [];
  Failure? startFailure;
  Failure? nextMutationFailure;

  void _throwInjected() {
    final failure = nextMutationFailure;
    if (failure == null) return;
    nextMutationFailure = null;
    throw failure;
  }

  @override
  Future<NavigationSession> start({
    required int itineraryId,
    required String idempotencyKey,
  }) async {
    calls.add('start:$itineraryId:$idempotencyKey');
    final failure = startFailure;
    if (failure != null) {
      startFailure = null;
      throw failure;
    }
    return demo.start(itineraryId: itineraryId, idempotencyKey: idempotencyKey);
  }

  @override
  Future<NavigationSession> getById(int sessionId) async {
    calls.add('get:$sessionId');
    final failure = getFailures[sessionId];
    if (failure != null) throw failure;
    return others[sessionId] ?? demo.getById(sessionId);
  }

  @override
  Future<NavigationSession> reachItem({
    required int sessionId,
    required int itemId,
    required DateTime occurredAt,
  }) async {
    calls.add('reach:$itemId');
    _throwInjected();
    reachTimes.add(occurredAt);
    return demo.reachItem(
      sessionId: sessionId,
      itemId: itemId,
      occurredAt: occurredAt,
    );
  }

  @override
  Future<NavigationSession> skipItem({
    required int sessionId,
    required int itemId,
    required DateTime occurredAt,
  }) async {
    calls.add('skip:$itemId');
    _throwInjected();
    return demo.skipItem(
      sessionId: sessionId,
      itemId: itemId,
      occurredAt: occurredAt,
    );
  }

  @override
  Future<NavigationSession> depart({
    required int sessionId,
    required DateTime occurredAt,
  }) async {
    calls.add('depart');
    _throwInjected();
    return demo.depart(sessionId: sessionId, occurredAt: occurredAt);
  }

  @override
  Future<NavigationSession> complete(int sessionId) async {
    calls.add('complete:$sessionId');
    _throwInjected();
    final other = others.remove(sessionId);
    if (other != null) return other;
    if (getFailures.remove(sessionId) != null) {
      return ActiveTripDemoFixtures.createDemoSession(sessionId: sessionId);
    }
    return demo.complete(sessionId);
  }
}

final class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({required bool online}) : _online = online;

  bool _online;
  final _changes = StreamController<bool>.broadcast();

  void set(bool online) {
    _online = online;
    _changes.add(online);
  }

  Future<void> dispose() => _changes.close();

  @override
  Future<bool> get isConnected async => _online;

  @override
  Stream<bool> get onConnectivityChanged => _changes.stream;
}

final class FakeLocationTracker implements NavigationLocationTracker {
  NavigationLocationAccess access = NavigationLocationAccess.granted;
  final _controller = StreamController<NavigationPosition>.broadcast();

  bool get hasListener => _controller.hasListener;

  void emit(NavigationPosition position) => _controller.add(position);

  void dispose() => _controller.close();

  @override
  Future<NavigationLocationAccess> ensureAccess() async => access;

  @override
  Stream<NavigationPosition> watchPosition() => _controller.stream;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

/// Returns a straight two-point route from origin to destination.
final class FakeDirections implements RouteDirectionsRepository {
  int requests = 0;
  bool failing = false;
  final requestedModes = <TransportMode?>[];

  @override
  bool get isAvailable => true;

  @override
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
    TransportMode? transportMode,
  }) async {
    requests++;
    requestedModes.add(transportMode);
    if (failing) throw const NetworkFailure();
    return NavigationRoute(
      geometry: [origin, destination],
      distanceMeters: 1000,
      durationSeconds: 240,
      steps: [
        NavigationStep(
          instruction: 'Head north',
          direction: ManeuverDirection.straight,
          location: origin,
          distanceMeters: 1000,
        ),
        NavigationStep(
          instruction: 'Arrive at the stop',
          direction: ManeuverDirection.arrive,
          location: destination,
          distanceMeters: 0,
        ),
      ],
    );
  }
}
