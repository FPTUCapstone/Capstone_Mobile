import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/rerouting_proposal_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';

import '../../../../support/trip_alert_test_data.dart';
import 'active_trip_cubit_test.dart'
    show
        FakeAlertRepository,
        FakeLocationTracker,
        FakeNetworkInfo,
        FakeSessionRepository;

const _msg42 =
    'Your itinerary has been updated. Navigation continues on the new route.';
const _msg43 = 'Suggestion declined. Continuing on your current route.';
const _msg44 = 'No re-routing suggestion is available at the moment.';
const _msg127 =
    'TripMate is temporarily unable to process your request. '
    'Please check your connection and try again.';

void main() {
  late DateTime now;
  late FakeSessionRepository sessions;
  late FakeLocationTracker tracker;
  late FakeReroutingRepository rerouting;
  late FakeAlertRepository alerts;

  setUp(() {
    now = DateTime.utc(2026, 11, 25, 3, 5);
    sessions = FakeSessionRepository();
    tracker = FakeLocationTracker();
    alerts = FakeAlertRepository();
    rerouting = FakeReroutingRepository(
      TripAlertTestData.sampleRerouteProposal(),
    );
  });

  tearDown(() => tracker.dispose());

  Future<ActiveTripCubit> startedCubit({
    NetworkInfo? networkInfo,
    DateTime Function()? clock,
  }) async {
    final cubit = ActiveTripCubit(
      itineraryId: 101,
      sessionRepository: sessions,
      locationTracker: tracker,
      alertRepository: alerts,
      reroutingRepository: rerouting,
      networkInfo: networkInfo,
      clock: clock ?? () => now,
      idempotencyKey: 'start-key',
    );
    await cubit.start();
    await pumpEventQueue();
    return cubit;
  }

  test('opening an alert loads the proposal and shows the sheet', () async {
    final cubit = await startedCubit();

    await cubit.openRerouteProposal(rerouteAlert());

    expect(rerouting.calls, ['get:9001:77']);
    expect(cubit.state.activeRerouteProposal?.proposalId, 77);
    expect(cubit.state.isRerouteSheetVisible, isTrue);
    expect(cubit.state.isSubmitting, isFalse);
    await cubit.close();
  });

  test('an alert without a proposal id never loads one', () async {
    final cubit = await startedCubit();

    await cubit.openRerouteProposal(rerouteAlert(proposalId: null));

    expect(rerouting.calls, isEmpty);
    expect(cubit.state.activeRerouteProposal, isNull);
    expect(cubit.state.isRerouteSheetVisible, isFalse);
    await cubit.close();
  });

  test('closed or expired proposals are never shown (MSG44)', () async {
    final cubit = await startedCubit();
    for (final status in [
      RerouteStatus.accepted,
      RerouteStatus.declined,
      RerouteStatus.expired,
    ]) {
      rerouting.proposal = TripAlertTestData.sampleRerouteProposal(
        status: status,
        expiresAt: now.add(const Duration(minutes: 10)),
      );

      await cubit.openRerouteProposal(rerouteAlert());

      expect(cubit.state.activeRerouteProposal, isNull, reason: '$status');
      expect(cubit.state.isRerouteSheetVisible, isFalse);
      expect(cubit.state.feedback?.message, _msg44);
    }
    await cubit.close();
  });

  test('a proposal past expiresAt on the device clock is not shown', () async {
    rerouting.proposal = TripAlertTestData.sampleRerouteProposal(
      expiresAt: now.subtract(const Duration(seconds: 1)),
    );
    final cubit = await startedCubit();

    await cubit.openRerouteProposal(rerouteAlert());

    expect(cubit.state.activeRerouteProposal, isNull);
    expect(cubit.state.feedback?.message, _msg44);
    await cubit.close();
  });

  test('a missing proposal shows MSG44 without a retry', () async {
    rerouting.getFailure = const ReroutingFailure(
      _msg44,
      reason: ReroutingFailureReason.notFound,
    );
    final cubit = await startedCubit();

    await cubit.openRerouteProposal(rerouteAlert());

    expect(cubit.state.feedback?.message, _msg44);
    expect(cubit.state.feedback?.canRetry, isFalse);
    expect(cubit.state.isSubmitting, isFalse);
    await cubit.close();
  });

  test('a transport failure on load offers Retry with MSG127', () async {
    rerouting.getFailure = const ServerFailure(_msg127);
    final cubit = await startedCubit();

    await cubit.openRerouteProposal(rerouteAlert());

    expect(cubit.state.feedback?.message, _msg127);
    expect(cubit.state.feedback?.canRetry, isTrue);

    rerouting.getFailure = null;
    await cubit.retryLastAction();
    expect(cubit.state.activeRerouteProposal?.proposalId, 77);
    await cubit.close();
  });

  test('accepting swaps in the new session and resets guidance', () async {
    final cubit = await startedCubit();
    await cubit.openRerouteProposal(rerouteAlert());
    final alertLoads = alerts.listCalls.length;
    expect(cubit.state.targetItemId, 1001);

    await cubit.acceptRerouteProposal();
    await pumpEventQueue();

    expect(rerouting.calls, ['get:9001:77', 'accept:9001:77']);
    expect(cubit.state.itineraryVersion, 2);
    expect(cubit.state.session, rerouting.acceptedSession());
    expect(cubit.state.targetItemId, 2001);
    expect(cubit.state.route, isNull);
    expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.accepted);
    expect(cubit.state.isRerouteSheetVisible, isFalse);
    expect(cubit.state.isSubmitting, isFalse);
    expect(cubit.state.feedback?.message, _msg42);
    expect(alerts.listCalls.length, greaterThan(alertLoads));
    await cubit.close();
  });

  test('a double tap on Accept sends one request', () async {
    final cubit = await startedCubit();
    await cubit.openRerouteProposal(rerouteAlert());
    rerouting.acceptGate = Completer<void>();

    final first = cubit.acceptRerouteProposal();
    final second = cubit.acceptRerouteProposal();
    await pumpEventQueue();
    expect(cubit.state.isSubmitting, isTrue);
    rerouting.acceptGate!.complete();
    await Future.wait([first, second]);

    expect(rerouting.calls.where((c) => c.startsWith('accept')).length, 1);
    await cubit.close();
  });

  test(
    'a closed proposal on accept drops it, says MSG44 and refreshes',
    () async {
      final cubit = await startedCubit();
      await cubit.openRerouteProposal(rerouteAlert());
      sessions.calls.clear();
      final alertLoads = alerts.listCalls.length;
      rerouting.acceptFailure = const ReroutingFailure(
        _msg44,
        reason: ReroutingFailureReason.expired,
      );

      await cubit.acceptRerouteProposal();
      await pumpEventQueue();

      expect(cubit.state.activeRerouteProposal, isNull);
      expect(cubit.state.isRerouteSheetVisible, isFalse);
      expect(cubit.state.feedback?.message, _msg44);
      expect(cubit.state.feedback?.isError, isTrue);
      expect(cubit.state.itineraryVersion, 1);
      expect(sessions.calls, contains('get:9001'));
      expect(alerts.listCalls.length, greaterThan(alertLoads));
      await cubit.close();
    },
  );

  test('a server failure on accept keeps the proposal and can retry', () async {
    final cubit = await startedCubit();
    await cubit.openRerouteProposal(rerouteAlert());
    rerouting.acceptFailure = const ServerFailure(_msg127);

    await cubit.acceptRerouteProposal();

    expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.pending);
    expect(cubit.state.itineraryVersion, 1);
    expect(cubit.state.feedback?.message, _msg127);
    expect(cubit.state.feedback?.canRetry, isTrue);
    expect(cubit.state.isSubmitting, isFalse);

    rerouting.acceptFailure = null;
    await cubit.retryLastAction();
    await pumpEventQueue();
    expect(cubit.state.itineraryVersion, 2);
    expect(cubit.state.feedback?.message, _msg42);
    await cubit.close();
  });

  test(
    'keeping the current route declines without touching the plan',
    () async {
      final cubit = await startedCubit();
      await cubit.openRerouteProposal(rerouteAlert());
      final sessionBefore = cubit.state.session;

      await cubit.declineRerouteProposal();

      expect(rerouting.calls, ['get:9001:77', 'reject:9001:77']);
      expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.declined);
      expect(cubit.state.isRerouteSheetVisible, isFalse);
      expect(cubit.state.session, sessionBefore);
      expect(cubit.state.itineraryVersion, 1);
      expect(cubit.state.feedback?.message, _msg43);
      await cubit.close();
    },
  );

  test('a closed proposal on decline says MSG44', () async {
    final cubit = await startedCubit();
    await cubit.openRerouteProposal(rerouteAlert());
    rerouting.rejectFailure = const ReroutingFailure(
      _msg44,
      reason: ReroutingFailureReason.closed,
    );

    await cubit.declineRerouteProposal();

    expect(cubit.state.activeRerouteProposal, isNull);
    expect(cubit.state.feedback?.message, _msg44);
    await cubit.close();
  });

  test('offline accept fails fast and can be retried', () async {
    final network = FakeNetworkInfo(online: true);
    final cubit = await startedCubit(networkInfo: network);
    await cubit.openRerouteProposal(rerouteAlert());
    network.set(false);
    await pumpEventQueue();

    await cubit.acceptRerouteProposal();

    expect(rerouting.calls, ['get:9001:77']);
    expect(cubit.state.feedback?.message, ActiveTripCubit.offlineMessage);
    expect(cubit.state.feedback?.canRetry, isTrue);

    network.set(true);
    await pumpEventQueue();
    await cubit.retryLastAction();
    await pumpEventQueue();
    expect(rerouting.calls, contains('accept:9001:77'));
    await cubit.close();
    await network.dispose();
  });

  test('the proposal expires on its own at expiresAt', () async {
    rerouting.proposal = TripAlertTestData.sampleRerouteProposal(
      expiresAt: DateTime.now().add(const Duration(milliseconds: 80)),
    );
    final cubit = await startedCubit(clock: DateTime.now);
    await cubit.openRerouteProposal(rerouteAlert());
    expect(cubit.state.isRerouteSheetVisible, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.expired);
    expect(cubit.state.isRerouteSheetVisible, isFalse);
    expect(cubit.state.feedback?.message, _msg44);
    expect(cubit.state.itineraryVersion, 1);
    await cubit.close();
  });

  test('an expired proposal refreshes alerts so Review disappears', () async {
    alerts.persisted
      ..clear()
      ..add(rerouteAlert());
    rerouting.proposal = TripAlertTestData.sampleRerouteProposal(
      expiresAt: DateTime.now().add(const Duration(milliseconds: 80)),
    );
    final cubit = await startedCubit(clock: DateTime.now);
    expect(cubit.state.alerts.single.reroutingProposalId, 77);
    await cubit.openRerouteProposal(rerouteAlert());
    // The Backend hides a proposal once it is past its TTL.
    alerts.persisted
      ..clear()
      ..add(rerouteAlert(proposalId: null));

    await Future<void>.delayed(const Duration(milliseconds: 250));
    await pumpEventQueue();

    expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.expired);
    expect(cubit.state.alerts.single.reroutingProposalId, isNull);
    expect(cubit.state.alerts.single.rerouteProposalAvailable, isFalse);
    await cubit.close();
  });

  test('an unavailable proposal found on open refreshes alerts', () async {
    final cubit = await startedCubit();
    for (final unavailable in [
      () => rerouting.proposal = TripAlertTestData.sampleRerouteProposal(
        status: RerouteStatus.expired,
        expiresAt: now.add(const Duration(minutes: 10)),
      ),
      () => rerouting.getFailure = const ReroutingFailure(
        _msg44,
        reason: ReroutingFailureReason.notFound,
      ),
    ]) {
      unavailable();
      final loadsBefore = alerts.listCalls.length;

      await cubit.openRerouteProposal(rerouteAlert());
      await pumpEventQueue();

      expect(cubit.state.feedback?.message, _msg44);
      expect(alerts.listCalls.length, greaterThan(loadsBefore));
      rerouting.getFailure = null;
    }
    await cubit.close();
  });

  test('a finished trip ignores re-routing actions', () async {
    final cubit = await startedCubit();
    await cubit.openRerouteProposal(rerouteAlert());
    await cubit.finish();
    rerouting.calls.clear();

    await cubit.acceptRerouteProposal();
    await cubit.declineRerouteProposal();
    await cubit.openRerouteProposal(rerouteAlert());

    expect(rerouting.calls, isEmpty);
    expect(cubit.state.isRerouteSheetVisible, isFalse);
    await cubit.close();
  });
}

/// An alert as the Backend sends it when a re-routing proposal is attached.
TripAlert rerouteAlert({int? proposalId = 77}) => TripAlert(
  id: '42',
  title: 'Severe weather',
  description: 'Heavy rain expected.',
  severity: AlertSeverity.critical,
  type: TripAlertType.weather,
  affectedStopName: 'Han Market',
  timestamp: DateTime.utc(2026, 11, 25, 3),
  messageCode: 'trip_alert.severe_weather',
  affectedItemId: 1002,
  reroutingProposalId: proposalId,
);

final class FakeReroutingRepository implements ReroutingProposalRepository {
  FakeReroutingRepository(this.proposal);

  RerouteProposal proposal;
  Failure? getFailure;
  Failure? acceptFailure;
  Failure? rejectFailure;
  Completer<void>? acceptGate;
  final List<String> calls = [];

  /// The session the Backend returns after accepting: version 2 with new item
  /// ids.
  NavigationSession acceptedSession() {
    final base = ActiveTripDemoFixtures.createDemoSession();
    NavigationSessionItem item(int id, int sequence, String name) =>
        NavigationSessionItem(
          itemId: id,
          sequenceNo: sequence,
          poiId: 50 + sequence,
          poiName: name,
          latitude: 16.05,
          longitude: 108.22,
          plannedArrival: DateTime.utc(2026, 11, 25, 6 + sequence),
          plannedDeparture: DateTime.utc(2026, 11, 25, 6 + sequence, 30),
          isMandatory: false,
          status: NavigationItemStatus.pending,
          reachedAt: null,
          skippedAt: null,
        );
    return NavigationSession(
      sessionId: base.sessionId,
      itineraryId: base.itineraryId,
      itineraryVersion: 2,
      state: NavigationSessionState.navigating,
      completionReason: null,
      startedAt: DateTime.utc(2026, 11, 25, 2),
      expiresAt: DateTime.utc(2026, 11, 25, 16),
      endedAt: null,
      exploringItemId: null,
      nextItemId: 2001,
      items: [item(2001, 1, 'Helio Center'), item(2002, 2, 'Cầu Rồng')],
    );
  }

  @override
  Future<RerouteProposal> getProposal({
    required int sessionId,
    required int proposalId,
  }) async {
    calls.add('get:$sessionId:$proposalId');
    final failure = getFailure;
    if (failure != null) throw failure;
    return proposal;
  }

  @override
  Future<NavigationSession> acceptProposal({
    required int sessionId,
    required int proposalId,
  }) async {
    calls.add('accept:$sessionId:$proposalId');
    await acceptGate?.future;
    final failure = acceptFailure;
    if (failure != null) throw failure;
    return acceptedSession();
  }

  @override
  Future<void> rejectProposal({
    required int sessionId,
    required int proposalId,
  }) async {
    calls.add('reject:$sessionId:$proposalId');
    final failure = rejectFailure;
    if (failure != null) throw failure;
  }
}
