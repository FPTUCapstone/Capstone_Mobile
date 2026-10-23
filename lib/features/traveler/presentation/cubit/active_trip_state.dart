import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/weather_advisory.dart';

enum ActiveTripStatus {
  navigationInitial,
  navigationAcquiringPosition,
  navigationActive,
  navigationOffRouteDeviation,
  navigationPausedBattery,
  navigationArrivedAtWaypoint,
  navigationTripCompleted,
  navigationPermissionDenied,
  navigationLocationServiceDisabled,
  navigationPositionUnavailable,
}

/// Lifecycle of the server navigation session behind the page.
enum ActiveTripLoadStatus { loading, ready, conflict, failed }

enum AlertRefreshStatus { idle, loading, success, failure }

/// One-shot message for the Traveler; [id] distinguishes repeated messages.
final class ActiveTripFeedback extends Equatable {
  const ActiveTripFeedback({
    required this.id,
    required this.message,
    this.isError = false,
    this.canRetry = false,
  });

  final int id;
  final String message;
  final bool isError;

  /// The failed action can be sent again with [ActiveTripCubit.retryLastAction].
  final bool canRetry;

  @override
  List<Object?> get props => [id, message, isError, canRetry];
}

final class ActiveTripState extends Equatable {
  const ActiveTripState({
    this.status = ActiveTripStatus.navigationInitial,
    required this.itineraryId,
    this.itineraryTitle = 'Active Trip',
    this.itineraryVersion = 1,
    this.loadStatus = ActiveTripLoadStatus.loading,
    this.loadErrorMessage,
    this.canRetryLoad = true,
    this.conflictSession,
    this.conflictSessionId,
    this.session,
    this.targetItemId,
    this.route,
    this.isGuidanceAvailable = false,
    this.currentManeuver,
    this.distanceToTargetMeters,
    this.remainingDurationSeconds,
    this.currentLatitude,
    this.currentLongitude,
    this.arrivalPromptItemId,
    this.isSubmitting = false,
    this.feedback,
    this.isOnline = true,
    this.alerts = const [],
    this.alertRefreshStatus = AlertRefreshStatus.idle,
    this.alertRefreshError,
    this.activeBannerAlert,
    this.activeWeatherAdvisory,
    this.activeRerouteProposal,
    this.isRerouteSheetVisible = false,
    this.statusMessage,
    this.isDemoMode = false,
  });

  final ActiveTripStatus status;
  final int itineraryId;
  final String itineraryTitle;
  final int itineraryVersion;
  final ActiveTripLoadStatus loadStatus;
  final String? loadErrorMessage;

  /// False when retrying cannot help (outside the trip window, itinerary not
  /// Active, no access…): the failure screen then offers only "Go back".
  final bool canRetryLoad;

  /// Open session of another itinerary that blocks starting this one; null
  /// when the Traveler can no longer read it but can still end it.
  final NavigationSession? conflictSession;
  final int? conflictSessionId;
  final NavigationSession? session;

  /// Stop the Traveler is heading to; null while exploring or when no
  /// reachable stop remains.
  final int? targetItemId;
  final NavigationRoute? route;
  final bool isGuidanceAvailable;
  final ActiveTripManeuver? currentManeuver;
  final double? distanceToTargetMeters;
  final double? remainingDurationSeconds;
  final double? currentLatitude;
  final double? currentLongitude;

  /// Stop detected by GPS that awaits the Traveler's confirmation.
  final int? arrivalPromptItemId;
  final bool isSubmitting;
  final ActiveTripFeedback? feedback;
  final bool isOnline;
  final List<TripAlert> alerts;
  final AlertRefreshStatus alertRefreshStatus;
  final String? alertRefreshError;
  final TripAlert? activeBannerAlert;
  final WeatherAdvisory? activeWeatherAdvisory;
  final RerouteProposal? activeRerouteProposal;
  final bool isRerouteSheetVisible;
  final String? statusMessage;
  final bool isDemoMode;

  List<NavigationSessionItem> get items => session?.items ?? const [];
  NavigationSessionItem? get targetItem => session?.itemById(targetItemId);
  NavigationSessionItem? get exploringItem => session?.exploringItem;
  NavigationSessionItem? get arrivalPromptItem =>
      session?.itemById(arrivalPromptItemId);
  bool get isExploring => session?.isExploring ?? false;
  bool get hasPendingItems => session?.hasPendingItems ?? false;
  int get reachedWaypointsCount => session?.reachedCount ?? 0;
  int get totalWaypointsCount => items.length;
  bool get hasPendingRerouteProposal =>
      activeRerouteProposal != null &&
      activeRerouteProposal!.status == RerouteStatus.pending;
  bool get isTerminal => status == ActiveTripStatus.navigationTripCompleted;

  ActiveTripState copyWith({
    ActiveTripStatus? status,
    String? itineraryTitle,
    int? itineraryVersion,
    ActiveTripLoadStatus? loadStatus,
    String? loadErrorMessage,
    bool? canRetryLoad,
    bool clearLoadError = false,
    NavigationSession? conflictSession,
    int? conflictSessionId,
    bool clearConflictSession = false,
    NavigationSession? session,
    int? targetItemId,
    bool clearTarget = false,
    NavigationRoute? route,
    bool clearRoute = false,
    bool? isGuidanceAvailable,
    ActiveTripManeuver? currentManeuver,
    bool clearManeuver = false,
    double? distanceToTargetMeters,
    bool clearDistance = false,
    double? remainingDurationSeconds,
    bool clearRemainingDuration = false,
    double? currentLatitude,
    double? currentLongitude,
    int? arrivalPromptItemId,
    bool clearArrivalPrompt = false,
    bool? isSubmitting,
    ActiveTripFeedback? feedback,
    bool? isOnline,
    List<TripAlert>? alerts,
    AlertRefreshStatus? alertRefreshStatus,
    String? alertRefreshError,
    bool clearAlertRefreshError = false,
    TripAlert? activeBannerAlert,
    bool clearBannerAlert = false,
    WeatherAdvisory? activeWeatherAdvisory,
    bool clearWeatherAdvisory = false,
    RerouteProposal? activeRerouteProposal,
    bool? isRerouteSheetVisible,
    String? statusMessage,
  }) {
    return ActiveTripState(
      status: status ?? this.status,
      itineraryId: itineraryId,
      itineraryTitle: itineraryTitle ?? this.itineraryTitle,
      itineraryVersion: itineraryVersion ?? this.itineraryVersion,
      loadStatus: loadStatus ?? this.loadStatus,
      loadErrorMessage: clearLoadError
          ? null
          : (loadErrorMessage ?? this.loadErrorMessage),
      canRetryLoad: canRetryLoad ?? this.canRetryLoad,
      conflictSession: clearConflictSession
          ? null
          : (conflictSession ?? this.conflictSession),
      conflictSessionId: clearConflictSession
          ? null
          : (conflictSessionId ?? this.conflictSessionId),
      session: session ?? this.session,
      targetItemId: clearTarget ? null : (targetItemId ?? this.targetItemId),
      route: clearRoute ? null : (route ?? this.route),
      isGuidanceAvailable: isGuidanceAvailable ?? this.isGuidanceAvailable,
      currentManeuver: clearManeuver
          ? null
          : (currentManeuver ?? this.currentManeuver),
      distanceToTargetMeters: clearDistance
          ? null
          : (distanceToTargetMeters ?? this.distanceToTargetMeters),
      remainingDurationSeconds: clearRemainingDuration
          ? null
          : (remainingDurationSeconds ?? this.remainingDurationSeconds),
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      arrivalPromptItemId: clearArrivalPrompt
          ? null
          : (arrivalPromptItemId ?? this.arrivalPromptItemId),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      feedback: feedback ?? this.feedback,
      isOnline: isOnline ?? this.isOnline,
      alerts: alerts ?? this.alerts,
      alertRefreshStatus: alertRefreshStatus ?? this.alertRefreshStatus,
      alertRefreshError: clearAlertRefreshError
          ? null
          : (alertRefreshError ?? this.alertRefreshError),
      activeBannerAlert: clearBannerAlert
          ? null
          : (activeBannerAlert ?? this.activeBannerAlert),
      activeWeatherAdvisory: clearWeatherAdvisory
          ? null
          : (activeWeatherAdvisory ?? this.activeWeatherAdvisory),
      activeRerouteProposal:
          activeRerouteProposal ?? this.activeRerouteProposal,
      isRerouteSheetVisible:
          isRerouteSheetVisible ?? this.isRerouteSheetVisible,
      statusMessage: statusMessage ?? this.statusMessage,
      isDemoMode: isDemoMode,
    );
  }

  @override
  List<Object?> get props => [
    status,
    itineraryId,
    itineraryTitle,
    itineraryVersion,
    loadStatus,
    loadErrorMessage,
    canRetryLoad,
    conflictSession,
    conflictSessionId,
    session,
    targetItemId,
    route,
    isGuidanceAvailable,
    currentManeuver,
    distanceToTargetMeters,
    remainingDurationSeconds,
    currentLatitude,
    currentLongitude,
    arrivalPromptItemId,
    isSubmitting,
    feedback,
    isOnline,
    alerts,
    alertRefreshStatus,
    alertRefreshError,
    activeBannerAlert,
    activeWeatherAdvisory,
    activeRerouteProposal,
    isRerouteSheetVisible,
    statusMessage,
    isDemoMode,
  ];
}
