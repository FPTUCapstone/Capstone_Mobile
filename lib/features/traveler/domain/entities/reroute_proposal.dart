import 'package:equatable/equatable.dart';

enum RerouteStatus { pending, accepted, declined, expired }

/// How a proposed stop differs from the plan in force (UC-15 `change`).
enum RerouteStopChange { kept, added, moved }

/// One stop of the current or the proposed plan. [change] is set on proposed
/// stops only.
final class RerouteStop extends Equatable {
  const RerouteStop({
    required this.name,
    required this.plannedArrival,
    required this.plannedDeparture,
    this.isMandatory = false,
    this.change,
  });

  final String name;
  final DateTime plannedArrival;
  final DateTime plannedDeparture;
  final bool isMandatory;
  final RerouteStopChange? change;

  @override
  List<Object?> get props => [
    name,
    plannedArrival,
    plannedDeparture,
    isMandatory,
    change,
  ];
}

/// Why the Backend proposed a new plan: the alert [code]
/// (`trip_alert.severe_weather`…), the engine [strategy] and the affected POI.
final class RerouteReason extends Equatable {
  const RerouteReason({
    required this.code,
    required this.strategy,
    this.affectedPoiName,
  });

  final String code;
  final String strategy;
  final String? affectedPoiName;

  @override
  List<Object?> get props => [code, strategy, affectedPoiName];
}

/// A Backend-computed alternative for the rest of the trip (UC-15). It changes
/// nothing until the Traveler accepts it (BR-33).
final class RerouteProposal extends Equatable {
  const RerouteProposal({
    required this.proposalId,
    required this.incidentId,
    required this.status,
    required this.reason,
    required this.currentStops,
    required this.proposedStops,
    required this.removedStops,
    required this.affectedStops,
    required this.travelTimeDiffMinutes,
    required this.arrivalTimeDiffMinutes,
    required this.proposedAt,
    required this.expiresAt,
    this.decidedAt,
  });

  final int proposalId;
  final int incidentId;
  final RerouteStatus status;
  final RerouteReason reason;
  final List<RerouteStop> currentStops;
  final List<RerouteStop> proposedStops;
  final List<String> removedStops;
  final List<String> affectedStops;
  final int travelTimeDiffMinutes;
  final int arrivalTimeDiffMinutes;
  final DateTime proposedAt;
  final DateTime expiresAt;
  final DateTime? decidedAt;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// The Traveler may still accept or decline it.
  bool isActionableAt(DateTime now) =>
      status == RerouteStatus.pending && !isExpiredAt(now);

  RerouteProposal copyWith({RerouteStatus? status, DateTime? decidedAt}) {
    return RerouteProposal(
      proposalId: proposalId,
      incidentId: incidentId,
      status: status ?? this.status,
      reason: reason,
      currentStops: currentStops,
      proposedStops: proposedStops,
      removedStops: removedStops,
      affectedStops: affectedStops,
      travelTimeDiffMinutes: travelTimeDiffMinutes,
      arrivalTimeDiffMinutes: arrivalTimeDiffMinutes,
      proposedAt: proposedAt,
      expiresAt: expiresAt,
      decidedAt: decidedAt ?? this.decidedAt,
    );
  }

  @override
  List<Object?> get props => [
    proposalId,
    incidentId,
    status,
    reason,
    currentStops,
    proposedStops,
    removedStops,
    affectedStops,
    travelTimeDiffMinutes,
    arrivalTimeDiffMinutes,
    proposedAt,
    expiresAt,
    decidedAt,
  ];
}
