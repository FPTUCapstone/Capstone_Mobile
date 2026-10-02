import 'package:flutter_bloc/flutter_bloc.dart';
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
    ActiveTripStatus initialStatus = ActiveTripStatus.navigationActive,
    bool isDemoMode = true,
  }) : super(
         _createInitialState(
           itineraryId: itineraryId,
           itineraryTitle: itineraryTitle,
           itineraryVersion: itineraryVersion,
           initialWaypoints: initialWaypoints,
           initialAlerts: initialAlerts,
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
    required ActiveTripStatus initialStatus,
    required bool isDemoMode,
  }) {
    final alerts = initialAlerts ?? ActiveTripDemoFixtures.createSampleAlerts();
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
      currentManeuver: ActiveTripDemoFixtures.defaultManeuver,
      isDemoMode: isDemoMode,
    );
  }

  /// System position update from GPS stream.
  void updatePosition({required double latitude, required double longitude}) {
    if (state.status == ActiveTripStatus.navigationTripCompleted) return;

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
  void onSystemDetectedArrival() {
    if (state.waypoints.isEmpty) return;
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
    final updatedAlerts = [alert, ...state.alerts];
    emit(state.copyWith(alerts: updatedAlerts, activeBannerAlert: alert));
  }

  /// Opens reroute proposal sheet for user review.
  void openRerouteProposal([RerouteProposal? proposal]) {
    final toOpen =
        proposal ??
        state.activeRerouteProposal ??
        ActiveTripDemoFixtures.createSampleRerouteProposal();

    emit(
      state.copyWith(
        activeRerouteProposal: toOpen,
        isRerouteSheetVisible: true,
      ),
    );
  }

  /// Closes proposal sheet without decision.
  void closeRerouteProposalSheet() {
    emit(state.copyWith(isRerouteSheetVisible: false));
  }

  /// UC-15 Traveler accepts the reroute proposal.
  /// Explicit consent creates a new itinerary version (V+1).
  void acceptRerouteProposal() {
    final proposal = state.activeRerouteProposal;
    if (proposal == null) return;

    final acceptedProposal = proposal.copyWith(status: RerouteStatus.accepted);
    final nextVersion = state.itineraryVersion + 1;

    // In demo preview, simulate applying shelter stop
    final updatedWaypoints = List<ActiveTripWaypoint>.from(state.waypoints);
    if (updatedWaypoints.length >= 4) {
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
  void declineRerouteProposal() {
    final proposal = state.activeRerouteProposal;
    if (proposal == null) return;

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
  void expireRerouteProposal() {
    final proposal = state.activeRerouteProposal;
    if (proposal == null) return;

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
    emit(
      state.copyWith(
        status: ActiveTripStatus.navigationTripCompleted,
        statusMessage: 'Navigation session ended.',
      ),
    );
  }

  void setStatus(ActiveTripStatus newStatus) {
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
    onSystemDetectedArrival();
  }

  /// DEMO_ONLY: Injects a severe weather disruption with reroute proposal.
  void demoSimulateWeatherDisruption() {
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
    emit(state.copyWith(status: ActiveTripStatus.navigationAcquiringPosition));
  }

  /// DEMO_ONLY: Simulates GPS unavailable state.
  void demoSimulateGpsLost() {
    emit(
      state.copyWith(status: ActiveTripStatus.navigationPositionUnavailable),
    );
  }

  /// DEMO_ONLY: Simulates permission denied state.
  void demoSimulatePermissionDenied() {
    emit(state.copyWith(status: ActiveTripStatus.navigationPermissionDenied));
  }
}
