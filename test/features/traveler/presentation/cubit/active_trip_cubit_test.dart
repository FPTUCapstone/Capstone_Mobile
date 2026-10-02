import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_cubit.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';

void main() {
  group('ActiveTripCubit', () {
    late ActiveTripCubit cubit;

    setUp(() {
      cubit = ActiveTripCubit(
        itineraryId: 101,
        itineraryTitle: 'Đà Nẵng City Explorer',
        itineraryVersion: 1,
        initialWaypoints: ActiveTripDemoFixtures.createDefaultWaypoints(),
        initialAlerts: ActiveTripDemoFixtures.createSampleAlerts(),
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
}
