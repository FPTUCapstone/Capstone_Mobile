import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_waypoint.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/cubit/active_trip_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';

class ActiveTripCubit extends Cubit<ActiveTripState> {
  ActiveTripCubit({
    required int itineraryId,
    String itineraryTitle = 'Active Trip',
    int itineraryVersion = 1,
    List<ActiveTripWaypoint>? initialWaypoints,
    List<TripAlert>? initialAlerts,
    ActiveTripManeuver? initialManeuver,
    ActiveTripStatus initialStatus = ActiveTripStatus.navigationActive,
    bool isDemoMode = false,
  }) : super(
         _createInitialState(
           itineraryId: itineraryId,
           itineraryTitle: itineraryTitle,
           itineraryVersion: itineraryVersion,
           initialWaypoints: initialWaypoints,
           initialAlerts: initialAlerts,
           initialManeuver: initialManeuver,
           initialStatus: initialStatus,
           isDemoMode: isDemoMode,
         ),
       );

  static ActiveTripState _createInitialState({
    required int itineraryId,
    required String itineraryTitle,
    required int itineraryVersion,
    List<ActiveTripWaypoint>? initialWaypoints,
    List<TripAlert>? initialAlerts,
    ActiveTripManeuver? initialManeuver,
    required ActiveTripStatus initialStatus,
    required bool isDemoMode,
  }) {
    if (isDemoMode) {
      final alerts =
          initialAlerts ?? ActiveTripDemoFixtures.createSampleAlerts();
      final newestUndismissed = alerts.cast<TripAlert?>().firstWhere(
        (a) => a != null && !a.isDismissedFromBanner,
        orElse: () => null,
      );

      return ActiveTripState(
        itineraryId: itineraryId,
        itineraryTitle: itineraryTitle,
        itineraryVersion: itineraryVersion,
        status: initialStatus,
        waypoints:
            initialWaypoints ?? ActiveTripDemoFixtures.createDefaultWaypoints(),
        alerts: alerts,
        activeBannerAlert: newestUndismissed,
        currentManeuver:
            initialManeuver ?? ActiveTripDemoFixtures.defaultManeuver,
        isDemoMode: true,
      );
    }

    // Production (non-demo) state: truthful representation without fake fixtures.
    final waypoints = initialWaypoints ?? const [];
    final alerts = initialAlerts ?? const [];
    final newestUndismissed = alerts.cast<TripAlert?>().firstWhere(
      (a) => a != null && !a.isDismissedFromBanner,
      orElse: () => null,
    );

    return ActiveTripState(
      itineraryId: itineraryId,
      itineraryTitle: itineraryTitle,
      itineraryVersion: itineraryVersion,
      status: waypoints.isEmpty
          ? ActiveTripStatus.navigationPositionUnavailable
          : initialStatus,
      statusMessage: waypoints.isEmpty
          ? 'Waiting for route geometry and GPS signal...'
          : null,
      waypoints: waypoints,
      alerts: alerts,
      activeBannerAlert: newestUndismissed,
      currentManeuver: initialManeuver,
      isDemoMode: false,
    );
  }

  /// System position update from GPS stream.
  void updatePosition({required double latitude, required double longitude}) {
    if (state.isTerminal) return;

    emit(
      state.copyWith(
        currentLatitude: latitude,
        currentLongitude: longitude,
        status: state.status == ActiveTripStatus.navigationAcquiringPosition
            ? ActiveTripStatus.navigationActive
            : state.status,
      ),
    );
  }

  /// Production arrival semantics:
  /// When GPS sensor detects proximity to active waypoint, the SYSTEM marks
  /// it reached and advances to next waypoint.
  /// If navigation is terminal (stopped or completed), arrival callbacks are rejected.
  void onSystemDetectedArrival() {
    if (state.isTerminal || state.waypoints.isEmpty) return;
    final currentIndex = state.currentWaypointIndex;
    final updatedWaypoints = List<ActiveTripWaypoint>.from(state.waypoints);

    if (currentIndex >= 0 && currentIndex < updatedWaypoints.length) {
      updatedWaypoints[currentIndex] = updatedWaypoints[currentIndex].copyWith(
        isReached: true,
      );
    }

    final nextIndex = currentIndex + 1;
    if (nextIndex >= updatedWaypoints.length) {
      // Last waypoint reached -> Trip completed
      emit(
        state.copyWith(
          status: ActiveTripStatus.navigationTripCompleted,
          waypoints: updatedWaypoints,
          currentWaypointIndex: currentIndex,
          statusMessage: 'Trip completed! All scheduled stops reached.',
          isRerouteSheetVisible: false,
        ),
      );
    } else {
      // Advance to next waypoint
      emit(
        state.copyWith(
          status: ActiveTripStatus.navigationArrivedAtWaypoint,
          waypoints: updatedWaypoints,
          currentWaypointIndex: nextIndex,
          statusMessage:
              'Arrived at ${updatedWaypoints[currentIndex].name}. Next stop: ${updatedWaypoints[nextIndex].name}',
        ),
      );
    }
  }

  /// Dismisses banner alert. The alert REMAINS in alerts history.
  void dismissBannerAlert(String alertId) {
    final updatedAlerts = state.alerts.map((a) {
      if (a.id == alertId) {
        return a.copyWith(isDismissedFromBanner: true);
      }
      return a;
    }).toList();

    emit(state.copyWith(alerts: updatedAlerts, clearBannerAlert: true));
  }

  /// Adds an alert to the active feed and surfaces it in the banner if appropriate.
  void addAlert(TripAlert alert) {
    if (state.isTerminal) return;
    final updatedAlerts = [alert, ...state.alerts];
    emit(state.copyWith(alerts: updatedAlerts, activeBannerAlert: alert));
  }

  /// Opens reroute proposal sheet for user review.
  /// A proposal may be reviewed/actioned only when its status is pending.
  /// If proposal is null:
  /// - In production mode: does not invent or reopen non-pending proposals.
  /// - In demo mode: generates a sample demo proposal if none is active.
  void openRerouteProposal([RerouteProposal? proposal]) {
    if (state.isTerminal) return;
    final target = proposal ?? state.activeRerouteProposal;
    if (target == null) {
      if (!state.isDemoMode) return;
      final demoProposal = ActiveTripDemoFixtures.createSampleRerouteProposal();
      emit(
        state.copyWith(
          activeRerouteProposal: demoProposal,
          isRerouteSheetVisible: true,
        ),
      );
      return;
    }

    // Terminal proposals (accepted, declined, expired) cannot be reopened
    if (target.status != RerouteStatus.pending) return;

    emit(
      state.copyWith(
        activeRerouteProposal: target,
        isRerouteSheetVisible: true,
      ),
    );
  }

  /// Closes proposal sheet without decision.
  void closeRerouteProposalSheet() {
    if (!state.isRerouteSheetVisible) return;
    emit(state.copyWith(isRerouteSheetVisible: false));
  }

  /// UC-15 Traveler accepts the reroute proposal.
  /// Explicit consent creates a new itinerary version (V+1).
  /// Requires activeRerouteProposal != null and status == pending.
  void acceptRerouteProposal() {
    if (state.isTerminal) return;
    final proposal = state.activeRerouteProposal;
    if (proposal == null || proposal.status != RerouteStatus.pending) return;

    final acceptedProposal = proposal.copyWith(status: RerouteStatus.accepted);
    final nextVersion = state.itineraryVersion + 1;

    // In demo preview, simulate applying shelter stop
    final updatedWaypoints = List<ActiveTripWaypoint>.from(state.waypoints);
    if (state.isDemoMode && updatedWaypoints.length >= 4) {
      updatedWaypoints[3] = updatedWaypoints[3].copyWith(
        name: 'Helio Center [Indoor Shelter]',
      );
    }

    emit(
      state.copyWith(
        itineraryVersion: nextVersion,
        waypoints: updatedWaypoints,
        activeRerouteProposal: acceptedProposal,
        isRerouteSheetVisible: false,
        status: ActiveTripStatus.navigationActive,
        statusMessage:
            'Itinerary updated to v$nextVersion with weather-safe route.',
      ),
    );
  }

  /// UC-15 Traveler declines the reroute proposal.
  /// Current route and version remain active.
  /// Requires activeRerouteProposal != null and status == pending.
  void declineRerouteProposal() {
    if (state.isTerminal) return;
    final proposal = state.activeRerouteProposal;
    if (proposal == null || proposal.status != RerouteStatus.pending) return;

    final declinedProposal = proposal.copyWith(status: RerouteStatus.declined);
    emit(
      state.copyWith(
        activeRerouteProposal: declinedProposal,
        isRerouteSheetVisible: false,
        status: ActiveTripStatus.navigationActive,
        statusMessage: 'Reroute declined. Continuing on current itinerary.',
      ),
    );
  }

  /// Proposal expires. Current route remains active.
  /// Requires activeRerouteProposal != null and status == pending.
  void expireRerouteProposal() {
    if (state.isTerminal) return;
    final proposal = state.activeRerouteProposal;
    if (proposal == null || proposal.status != RerouteStatus.pending) return;

    final expiredProposal = proposal.copyWith(status: RerouteStatus.expired);
    emit(
      state.copyWith(
        activeRerouteProposal: expiredProposal,
        isRerouteSheetVisible: false,
        status: ActiveTripStatus.navigationActive,
        statusMessage: 'Suggestion expired. Current plan remains in force.',
      ),
    );
  }

  /// Traveler stops navigation session.
  void stopNavigation() {
    if (state.isTerminal) return;
    emit(
      state.copyWith(
        status: ActiveTripStatus.navigationTripCompleted,
        statusMessage: 'Navigation session ended.',
        isRerouteSheetVisible: false,
      ),
    );
  }

  void setStatus(ActiveTripStatus newStatus) {
    if (state.isTerminal) return;
    emit(state.copyWith(status: newStatus));
  }

  void setOnlineStatus(bool isOnline) {
    emit(state.copyWith(isOnline: isOnline));
  }

  // =========================================================================
  // DEMO_ONLY SIMULATION CONTROLS
  // Clearly isolated from production actions for visual review & testing
  // =========================================================================

  /// DEMO_ONLY: Simulates GPS arrival detection at current waypoint.
  void demoSimulateArrivalAtNextStop() {
    if (!state.isDemoMode || state.isTerminal) return;
    onSystemDetectedArrival();
  }

  /// DEMO_ONLY: Injects a severe weather disruption with reroute proposal.
  void demoSimulateWeatherDisruption() {
    if (!state.isDemoMode || state.isTerminal) return;
    final alert = TripAlert(
      id: 'demo-weather-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Severe weather warning',
      description:
          'Heavy rainfall (45 mm/h) detected along upcoming route segment.',
      severity: AlertSeverity.critical,
      type: TripAlertType.weather,
      affectedStopName: state.currentWaypoint?.name ?? 'Next stop',
      timestamp: DateTime.now(),
      rerouteProposalAvailable: true,
    );
    final proposal = ActiveTripDemoFixtures.createSampleRerouteProposal();

    emit(
      state.copyWith(
        alerts: [alert, ...state.alerts],
        activeBannerAlert: alert,
        activeRerouteProposal: proposal,
        status: ActiveTripStatus.navigationActive,
      ),
    );
  }

  /// DEMO_ONLY: Injects route deviation event (>500m).
  void demoSimulateRouteDeviation() {
    if (!state.isDemoMode || state.isTerminal) return;
    final alert = TripAlert(
      id: 'demo-deviation-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Off-route deviation detected',
      description: 'You have deviated from planned route by >500m.',
      severity: AlertSeverity.critical,
      type: TripAlertType.deviation,
      affectedStopName: 'Off-route segment',
      timestamp: DateTime.now(),
      rerouteProposalAvailable: true,
    );
    emit(
      state.copyWith(
        status: ActiveTripStatus.navigationOffRouteDeviation,
        alerts: [alert, ...state.alerts],
        activeBannerAlert: alert,
        activeRerouteProposal:
            ActiveTripDemoFixtures.createSampleRerouteProposal(),
      ),
    );
  }

  /// DEMO_ONLY: Toggles GPS acquiring state.
  void demoSimulateGpsAcquiring() {
    if (!state.isDemoMode || state.isTerminal) return;
    emit(state.copyWith(status: ActiveTripStatus.navigationAcquiringPosition));
  }

  /// DEMO_ONLY: Simulates GPS unavailable state.
  void demoSimulateGpsLost() {
    if (!state.isDemoMode || state.isTerminal) return;
    emit(
      state.copyWith(status: ActiveTripStatus.navigationPositionUnavailable),
    );
  }

  /// DEMO_ONLY: Simulates permission denied state.
  void demoSimulatePermissionDenied() {
    if (!state.isDemoMode || state.isTerminal) return;
    emit(state.copyWith(status: ActiveTripStatus.navigationPermissionDenied));
  }
}
