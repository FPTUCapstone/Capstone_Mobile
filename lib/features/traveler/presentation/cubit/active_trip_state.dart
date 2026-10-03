import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_waypoint.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';

enum ActiveTripStatus {
  navigationInitial,
  navigationAcquiringPosition,
  navigationActive,
  navigationOffRouteDeviation,
  navigationPausedBattery,
  navigationArrivedAtWaypoint,
  navigationTripCompleted,
  navigationPermissionDenied,
  navigationPositionUnavailable,
}

final class ActiveTripState extends Equatable {
  const ActiveTripState({
    this.status = ActiveTripStatus.navigationInitial,
    required this.itineraryId,
    this.itineraryTitle = 'Active Trip',
    this.itineraryVersion = 1,
    this.waypoints = const [],
    this.currentWaypointIndex = 0,
    this.currentManeuver,
    this.currentLatitude,
    this.currentLongitude,
    this.isOnline = true,
    this.alerts = const [],
    this.activeBannerAlert,
    this.activeRerouteProposal,
    this.isRerouteSheetVisible = false,
    this.statusMessage,
    this.isDemoMode = false,
  });

  final ActiveTripStatus status;
  final int itineraryId;
  final String itineraryTitle;
  final int itineraryVersion;
  final List<ActiveTripWaypoint> waypoints;
  final int currentWaypointIndex;
  final ActiveTripManeuver? currentManeuver;
  final double? currentLatitude;
  final double? currentLongitude;
  final bool isOnline;
  final List<TripAlert> alerts;
  final TripAlert? activeBannerAlert;
  final RerouteProposal? activeRerouteProposal;
  final bool isRerouteSheetVisible;
  final String? statusMessage;
  final bool isDemoMode;

  ActiveTripWaypoint? get currentWaypoint {
    if (waypoints.isEmpty ||
        currentWaypointIndex < 0 ||
        currentWaypointIndex >= waypoints.length) {
      return null;
    }
    return waypoints[currentWaypointIndex];
  }

  int get reachedWaypointsCount => waypoints.where((w) => w.isReached).length;
  int get totalWaypointsCount => waypoints.length;
  bool get hasPendingRerouteProposal =>
      activeRerouteProposal != null &&
      activeRerouteProposal!.status == RerouteStatus.pending;
  bool get isTerminal => status == ActiveTripStatus.navigationTripCompleted;

  ActiveTripState copyWith({
    ActiveTripStatus? status,
    int? itineraryId,
    String? itineraryTitle,
    int? itineraryVersion,
    List<ActiveTripWaypoint>? waypoints,
    int? currentWaypointIndex,
    ActiveTripManeuver? currentManeuver,
    double? currentLatitude,
    double? currentLongitude,
    bool? isOnline,
    List<TripAlert>? alerts,
    TripAlert? activeBannerAlert,
    bool clearBannerAlert = false,
    RerouteProposal? activeRerouteProposal,
    bool? isRerouteSheetVisible,
    String? statusMessage,
    bool? isDemoMode,
  }) {
    return ActiveTripState(
      status: status ?? this.status,
      itineraryId: itineraryId ?? this.itineraryId,
      itineraryTitle: itineraryTitle ?? this.itineraryTitle,
      itineraryVersion: itineraryVersion ?? this.itineraryVersion,
      waypoints: waypoints ?? this.waypoints,
      currentWaypointIndex: currentWaypointIndex ?? this.currentWaypointIndex,
      currentManeuver: currentManeuver ?? this.currentManeuver,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      isOnline: isOnline ?? this.isOnline,
      alerts: alerts ?? this.alerts,
      activeBannerAlert: clearBannerAlert
          ? null
          : (activeBannerAlert ?? this.activeBannerAlert),
      activeRerouteProposal:
          activeRerouteProposal ?? this.activeRerouteProposal,
      isRerouteSheetVisible:
          isRerouteSheetVisible ?? this.isRerouteSheetVisible,
      statusMessage: statusMessage ?? this.statusMessage,
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }

  @override
  List<Object?> get props => [
    status,
    itineraryId,
    itineraryTitle,
    itineraryVersion,
    waypoints,
    currentWaypointIndex,
    currentManeuver,
    currentLatitude,
    currentLongitude,
    isOnline,
    alerts,
    activeBannerAlert,
    activeRerouteProposal,
    isRerouteSheetVisible,
    statusMessage,
    isDemoMode,
  ];
}
