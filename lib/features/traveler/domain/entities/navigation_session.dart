import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

enum NavigationSessionState { navigating, exploring, completed }

enum NavigationCompletionReason { routeFinished, travelerStopped, expired }

enum NavigationItemStatus { pending, skipped, reached }

/// A Traveler's server-side UC-13 navigation session with its frozen stop snapshot.
final class NavigationSession extends Equatable {
  const NavigationSession({
    required this.sessionId,
    required this.itineraryId,
    required this.itineraryVersion,
    required this.state,
    required this.completionReason,
    required this.startedAt,
    required this.expiresAt,
    required this.endedAt,
    required this.exploringItemId,
    required this.nextItemId,
    required this.items,
    this.transportMode,
  });

  final int sessionId;
  final int itineraryId;
  final int itineraryVersion;
  final NavigationSessionState state;
  final NavigationCompletionReason? completionReason;
  final DateTime startedAt;
  final DateTime? expiresAt;
  final DateTime? endedAt;
  final int? exploringItemId;

  /// Backend-suggested next stop: the Pending stop with the lowest sequence.
  final int? nextItemId;
  final List<NavigationSessionItem> items;

  /// How the itinerary was planned; routes use the same mode. Null for manual
  /// itineraries.
  final TransportMode? transportMode;

  bool get isCompleted => state == NavigationSessionState.completed;
  bool get isExploring => state == NavigationSessionState.exploring;
  bool get hasPendingItems =>
      items.any((item) => item.status == NavigationItemStatus.pending);

  int get reachedCount =>
      items.where((item) => item.status == NavigationItemStatus.reached).length;
  int get skippedCount =>
      items.where((item) => item.status == NavigationItemStatus.skipped).length;
  int get pendingCount =>
      items.where((item) => item.status == NavigationItemStatus.pending).length;

  NavigationSessionItem? itemById(int? itemId) {
    if (itemId == null) return null;
    for (final item in items) {
      if (item.itemId == itemId) return item;
    }
    return null;
  }

  NavigationSessionItem? get exploringItem => itemById(exploringItemId);

  /// Stops that can still be reached: Pending first, then Skipped (revisit).
  List<NavigationSessionItem> get reachableItems =>
      items.where((item) => item.isReachable).toList(growable: false);

  NavigationSession copyWith({List<NavigationSessionItem>? items}) {
    return NavigationSession(
      sessionId: sessionId,
      itineraryId: itineraryId,
      itineraryVersion: itineraryVersion,
      state: state,
      completionReason: completionReason,
      startedAt: startedAt,
      expiresAt: expiresAt,
      endedAt: endedAt,
      exploringItemId: exploringItemId,
      nextItemId: nextItemId,
      items: items ?? this.items,
      transportMode: transportMode,
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    itineraryId,
    itineraryVersion,
    state,
    completionReason,
    startedAt,
    expiresAt,
    endedAt,
    exploringItemId,
    nextItemId,
    items,
    transportMode,
  ];
}

final class NavigationSessionItem extends Equatable {
  const NavigationSessionItem({
    required this.itemId,
    required this.sequenceNo,
    required this.poiId,
    required this.poiName,
    required this.latitude,
    required this.longitude,
    required this.plannedArrival,
    required this.plannedDeparture,
    required this.isMandatory,
    required this.status,
    required this.reachedAt,
    required this.skippedAt,
    this.stopNumber,
    this.transportModeFromPrevious,
  });

  final int itemId;

  /// Position in the itinerary, counting breaks too: gaps appear when a break
  /// sits between two stops, so screens show [displayNumber] instead.
  final int sequenceNo;

  /// 1-based position among the session's stops (no gaps).
  final int? stopNumber;
  final int poiId;
  final String poiName;
  final double latitude;
  final double longitude;
  final DateTime plannedArrival;
  final DateTime plannedDeparture;
  final bool isMandatory;
  final NavigationItemStatus status;
  final DateTime? reachedAt;
  final DateTime? skippedAt;

  /// Mode of the leg that reaches this stop, which the traveler may have
  /// changed per leg. Null for the first stop or when unknown; routing then
  /// uses the session's [NavigationSession.transportMode].
  final TransportMode? transportModeFromPrevious;

  /// The number shown on cards, lists and map markers.
  int get displayNumber => stopNumber ?? sequenceNo;

  bool get isReachable => status != NavigationItemStatus.reached;
  bool get isReached => status == NavigationItemStatus.reached;

  NavigationSessionItem copyWith({
    String? poiName,
    NavigationItemStatus? status,
    DateTime? reachedAt,
    DateTime? skippedAt,
    TransportMode? transportModeFromPrevious,
  }) {
    return NavigationSessionItem(
      itemId: itemId,
      sequenceNo: sequenceNo,
      poiId: poiId,
      poiName: poiName ?? this.poiName,
      latitude: latitude,
      longitude: longitude,
      plannedArrival: plannedArrival,
      plannedDeparture: plannedDeparture,
      isMandatory: isMandatory,
      status: status ?? this.status,
      reachedAt: reachedAt ?? this.reachedAt,
      skippedAt: skippedAt ?? this.skippedAt,
      stopNumber: stopNumber,
      transportModeFromPrevious:
          transportModeFromPrevious ?? this.transportModeFromPrevious,
    );
  }

  @override
  List<Object?> get props => [
    itemId,
    sequenceNo,
    poiId,
    poiName,
    latitude,
    longitude,
    plannedArrival,
    plannedDeparture,
    isMandatory,
    status,
    reachedAt,
    skippedAt,
    stopNumber,
    transportModeFromPrevious,
  ];
}
