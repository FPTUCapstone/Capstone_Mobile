import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';

void main() {
  group('ActiveTripCubit Demo Mode', () {
    late ActiveTripCubit cubit;

    setUp(() {
      cubit = ActiveTripCubit(
        itineraryId: 101,
        itineraryTitle: 'Đà Nẵng City Explorer',
        itineraryVersion: 1,
        initialWaypoints: ActiveTripDemoFixtures.createDefaultWaypoints(),
        initialAlerts: ActiveTripDemoFixtures.createSampleAlerts(),
        isDemoMode: true,
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state has navigationActive status and waypoints loaded', () {
      expect(cubit.state.status, ActiveTripStatus.navigationActive);
      expect(cubit.state.itineraryId, 101);
      expect(cubit.state.waypoints.length, 5);
      expect(cubit.state.currentWaypointIndex, 0);
      expect(
        cubit.state.currentWaypoint?.name,
        'Marble Mountains (Ngũ Hành Sơn)',
      );
    });

    test('updatePosition updates current coordinates', () {
      cubit.updatePosition(latitude: 16.0040, longitude: 108.2640);
      expect(cubit.state.currentLatitude, 16.0040);
      expect(cubit.state.currentLongitude, 108.2640);
    });

    test(
      'demoSimulatePermissionDenied transitions to navigationPermissionDenied status',
      () {
        cubit.demoSimulatePermissionDenied();
        expect(cubit.state.status, ActiveTripStatus.navigationPermissionDenied);
      },
    );

    test(
      'demoSimulateGpsLost transitions to navigationPositionUnavailable status',
      () {
        cubit.demoSimulateGpsLost();
        expect(
          cubit.state.status,
          ActiveTripStatus.navigationPositionUnavailable,
        );
      },
    );

    test(
      'automated system arrival detection advances waypoint per SRS (no manual arrival)',
      () {
        expect(cubit.state.currentWaypointIndex, 0);

        // Automated arrival at stop 1
        cubit.onSystemDetectedArrival();
        expect(cubit.state.currentWaypointIndex, 1);
        expect(cubit.state.waypoints[0].isReached, isTrue);
        expect(cubit.state.currentWaypoint?.name, 'Cơm Gà Bà Buội');

        // Automated arrival at stop 2
        cubit.onSystemDetectedArrival();
        expect(cubit.state.currentWaypointIndex, 2);
        expect(cubit.state.waypoints[1].isReached, isTrue);

        // Advance through remaining stops until complete
        cubit.onSystemDetectedArrival(); // Stop 3
        cubit.onSystemDetectedArrival(); // Stop 4
        cubit.onSystemDetectedArrival(); // Stop 5 (Final)

        expect(cubit.state.status, ActiveTripStatus.navigationTripCompleted);
        expect(cubit.state.reachedWaypointsCount, 5);
      },
    );

    test(
      'demoSimulateRouteDeviation switches status to navigationOffRouteDeviation',
      () {
        cubit.demoSimulateRouteDeviation();
        expect(
          cubit.state.status,
          ActiveTripStatus.navigationOffRouteDeviation,
        );
        expect(
          cubit.state.alerts.any((a) => a.type == TripAlertType.deviation),
          isTrue,
        );
      },
    );

    test(
      'dismissing banner alert keeps alert in alerts list for history sheet',
      () {
        final initialAlertsCount = cubit.state.alerts.length;
        expect(initialAlertsCount, greaterThan(0));

        final activeAlert = cubit.state.activeBannerAlert;
        expect(activeAlert, isNotNull);

        cubit.dismissBannerAlert(activeAlert!.id);

        expect(cubit.state.activeBannerAlert, isNull);
        expect(cubit.state.alerts.length, initialAlertsCount);
        expect(
          cubit.state.alerts
              .firstWhere((a) => a.id == activeAlert.id)
              .isDismissedFromBanner,
          isTrue,
        );
      },
    );

    test(
      're-routing consent gate: proposal presented and requires explicit decision',
      () {
        final proposal = ActiveTripDemoFixtures.createSampleRerouteProposal();
        cubit.openRerouteProposal(proposal);

        expect(cubit.state.isRerouteSheetVisible, isTrue);
        expect(cubit.state.activeRerouteProposal, isNotNull);
        expect(
          cubit.state.activeRerouteProposal?.status,
          RerouteStatus.pending,
        );

        // Traveler declines -> proposal marked declined, version remains 1
        cubit.declineRerouteProposal();
        expect(cubit.state.isRerouteSheetVisible, isFalse);
        expect(
          cubit.state.activeRerouteProposal?.status,
          RerouteStatus.declined,
        );
        expect(cubit.state.itineraryVersion, 1);
      },
    );

    test(
      're-routing consent gate: acceptance bumps version to V+1 and applies shelter stop',
      () {
        final proposal = ActiveTripDemoFixtures.createSampleRerouteProposal();
        cubit.openRerouteProposal(proposal);

        cubit.acceptRerouteProposal();
        expect(cubit.state.isRerouteSheetVisible, isFalse);
        expect(
          cubit.state.activeRerouteProposal?.status,
          RerouteStatus.accepted,
        );
        expect(cubit.state.itineraryVersion, 2);
        expect(cubit.state.waypoints[3].name, contains('Indoor Shelter'));
      },
    );

    test('re-routing expiry retains current route and version', () {
      final proposal = ActiveTripDemoFixtures.createSampleRerouteProposal();
      cubit.openRerouteProposal(proposal);

      cubit.expireRerouteProposal();
      expect(cubit.state.isRerouteSheetVisible, isFalse);
      expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.expired);
      expect(cubit.state.itineraryVersion, 1);
    });
  });

  group('Production / Demo Boundary in ActiveTripCubit', () {
    test('ActiveTripCubit defaults isDemoMode to false', () {
      final prodCubit = ActiveTripCubit(itineraryId: 202);
      expect(prodCubit.state.isDemoMode, isFalse);
      prodCubit.close();
    });

    test('production cubit does NOT automatically populate demo fixtures', () {
      final prodCubit = ActiveTripCubit(itineraryId: 202);

      expect(prodCubit.state.waypoints, isEmpty);
      expect(prodCubit.state.alerts, isEmpty);
      expect(prodCubit.state.currentManeuver, isNull);
      expect(prodCubit.state.activeRerouteProposal, isNull);
      expect(
        prodCubit.state.status,
        ActiveTripStatus.navigationPositionUnavailable,
      );
      expect(prodCubit.state.statusMessage, contains('Waiting for route'));

      prodCubit.close();
    });

    test('demo simulation methods cannot alter non-demo state', () {
      final prodCubit = ActiveTripCubit(itineraryId: 202);
      final initialStatus = prodCubit.state.status;

      // None of the demo simulation methods should affect non-demo state
      prodCubit.demoSimulatePermissionDenied();
      expect(prodCubit.state.status, initialStatus);

      prodCubit.demoSimulateGpsLost();
      expect(prodCubit.state.status, initialStatus);

      prodCubit.demoSimulateGpsAcquiring();
      expect(prodCubit.state.status, initialStatus);

      prodCubit.demoSimulateRouteDeviation();
      expect(prodCubit.state.status, initialStatus);
      expect(prodCubit.state.alerts, isEmpty);

      prodCubit.demoSimulateWeatherDisruption();
      expect(prodCubit.state.alerts, isEmpty);
      expect(prodCubit.state.activeRerouteProposal, isNull);

      prodCubit.demoSimulateArrivalAtNextStop();
      expect(prodCubit.state.currentWaypointIndex, 0);

      prodCubit.close();
    });

    test(
      'production cubit does not invent proposal when openRerouteProposal called with null',
      () {
        final prodCubit = ActiveTripCubit(itineraryId: 202);

        prodCubit.openRerouteProposal();

        expect(prodCubit.state.activeRerouteProposal, isNull);
        expect(prodCubit.state.isRerouteSheetVisible, isFalse);

        prodCubit.close();
      },
    );
  });

  group('Reroute Proposal Single-Decision & Terminal Lifecycle', () {
    test(
      'pending proposal -> accept -> version V+1 -> try open again -> try accept again -> version remains V+1',
      () {
        final cubit = ActiveTripCubit(
          itineraryId: 101,
          initialWaypoints: ActiveTripDemoFixtures.createDefaultWaypoints(),
          isDemoMode: true,
        );

        final proposal = ActiveTripDemoFixtures.createSampleRerouteProposal();
        cubit.openRerouteProposal(proposal);

        expect(cubit.state.isRerouteSheetVisible, isTrue);
        expect(
          cubit.state.activeRerouteProposal?.status,
          RerouteStatus.pending,
        );

        // 1. First acceptance -> transitions to accepted, version becomes 2
        cubit.acceptRerouteProposal();
        expect(cubit.state.itineraryVersion, 2);
        expect(
          cubit.state.activeRerouteProposal?.status,
          RerouteStatus.accepted,
        );
        expect(cubit.state.isRerouteSheetVisible, isFalse);

        // 2. Try to reopen accepted proposal -> blocked (isRerouteSheetVisible remains false)
        cubit.openRerouteProposal();
        expect(cubit.state.isRerouteSheetVisible, isFalse);

        // 3. Try accept again -> no-op, version remains exactly 2
        cubit.acceptRerouteProposal();
        expect(cubit.state.itineraryVersion, 2);

        cubit.close();
      },
    );

    test('declined proposal cannot later be accepted', () {
      final cubit = ActiveTripCubit(
        itineraryId: 101,
        initialWaypoints: ActiveTripDemoFixtures.createDefaultWaypoints(),
        isDemoMode: true,
      );

      final proposal = ActiveTripDemoFixtures.createSampleRerouteProposal();
      cubit.openRerouteProposal(proposal);
      cubit.declineRerouteProposal();

      expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.declined);
      expect(cubit.state.itineraryVersion, 1);

      // Try reopen -> blocked
      cubit.openRerouteProposal();
      expect(cubit.state.isRerouteSheetVisible, isFalse);

      // Try accept -> no-op, version unchanged
      cubit.acceptRerouteProposal();
      expect(cubit.state.itineraryVersion, 1);
      expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.declined);

      cubit.close();
    });

    test('expired proposal cannot later be accepted', () {
      final cubit = ActiveTripCubit(
        itineraryId: 101,
        initialWaypoints: ActiveTripDemoFixtures.createDefaultWaypoints(),
        isDemoMode: true,
      );

      final proposal = ActiveTripDemoFixtures.createSampleRerouteProposal();
      cubit.openRerouteProposal(proposal);
      cubit.expireRerouteProposal();

      expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.expired);
      expect(cubit.state.itineraryVersion, 1);

      // Try reopen -> blocked
      cubit.openRerouteProposal();
      expect(cubit.state.isRerouteSheetVisible, isFalse);

      // Try accept -> no-op, version unchanged
      cubit.acceptRerouteProposal();
      expect(cubit.state.itineraryVersion, 1);
      expect(cubit.state.activeRerouteProposal?.status, RerouteStatus.expired);

      cubit.close();
    });
  });
}
