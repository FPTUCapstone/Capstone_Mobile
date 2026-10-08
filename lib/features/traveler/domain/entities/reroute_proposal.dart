import 'package:equatable/equatable.dart';

enum RerouteStatus { pending, accepted, declined, expired }

/// Represents a proposed itinerary revision triggered by route deviation or alert (UC-15).
///
/// NOTE (REROUTE_COMPARISON_CONTRACT):
/// The core required SRS comparison fields are:
/// - [reason]
/// - [currentStops] vs [proposedStops]
/// - [travelTimeDiffMinutes]
/// - [arrivalTimeDiffMinutes]
/// - [affectedStops]
///
/// Supplementary metrics such as [costDiffVnd] and [distanceDiffKm] are strictly
/// optional presentation/demo metrics and NOT required production backend contracts.
final class RerouteProposal extends Equatable {
  const RerouteProposal({
    required this.proposalId,
    required this.reason,
    required this.currentStops,
    required this.proposedStops,
    required this.travelTimeDiffMinutes,
    required this.arrivalTimeDiffMinutes,
    required this.affectedStops,
    this.status = RerouteStatus.pending,
    required this.raisedAt,
    this.costDiffVnd,
    this.distanceDiffKm,
  });

  final String proposalId;
  final String reason;
  final List<String> currentStops;
  final List<String> proposedStops;
  final int travelTimeDiffMinutes;
  final int arrivalTimeDiffMinutes;
  final List<String> affectedStops;
  final RerouteStatus status;
  final DateTime raisedAt;
  final double? costDiffVnd;
  final double? distanceDiffKm;

  RerouteProposal copyWith({
    String? proposalId,
    String? reason,
    List<String>? currentStops,
    List<String>? proposedStops,
    int? travelTimeDiffMinutes,
    int? arrivalTimeDiffMinutes,
    List<String>? affectedStops,
    RerouteStatus? status,
    DateTime? raisedAt,
    double? costDiffVnd,
    double? distanceDiffKm,
  }) {
    return RerouteProposal(
      proposalId: proposalId ?? this.proposalId,
      reason: reason ?? this.reason,
      currentStops: currentStops ?? this.currentStops,
      proposedStops: proposedStops ?? this.proposedStops,
      travelTimeDiffMinutes:
          travelTimeDiffMinutes ?? this.travelTimeDiffMinutes,
      arrivalTimeDiffMinutes:
          arrivalTimeDiffMinutes ?? this.arrivalTimeDiffMinutes,
      affectedStops: affectedStops ?? this.affectedStops,
      status: status ?? this.status,
      raisedAt: raisedAt ?? this.raisedAt,
      costDiffVnd: costDiffVnd ?? this.costDiffVnd,
      distanceDiffKm: distanceDiffKm ?? this.distanceDiffKm,
    );
  }

  @override
  List<Object?> get props => [
    proposalId,
    reason,
    currentStops,
    proposedStops,
    travelTimeDiffMinutes,
    arrivalTimeDiffMinutes,
    affectedStops,
    status,
    raisedAt,
    costDiffVnd,
    distanceDiffKm,
  ];
}
