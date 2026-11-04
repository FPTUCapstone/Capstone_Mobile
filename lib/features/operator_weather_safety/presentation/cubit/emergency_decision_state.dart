import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';

enum EmergencyDecisionStage {
  loading,

  /// The impact is fresh and the Operator may fill in the decision.
  ready,

  /// Re-reading the impact before showing the confirmation.
  checkingImpact,
  awaitingConfirmation,
  submitting,

  /// The outcome of the last submit is unknown; only an identical retry is safe.
  ambiguous,
  succeeded,
  blocked,
  notFound,
}

enum EmergencyBlockReason {
  offline,
  unverifiedSessions,
  unsupportedAction,
  terminal,
  completed,
  forbidden,
  unavailable,
}

/// Holds no password: it travels only as an argument of the submit call.
final class EmergencyDecisionState extends Equatable {
  const EmergencyDecisionState({
    this.stage = EmergencyDecisionStage.loading,
    this.impact,
    this.blockReason,
    this.pendingDecision,
    this.impactChanged = false,
    this.failure,
    this.result,
  });

  final EmergencyDecisionStage stage;
  final EmergencyImpact? impact;
  final EmergencyBlockReason? blockReason;

  /// The decision being confirmed or retried, bound to a checked impact version.
  final EmergencyDecision? pendingDecision;

  /// The impact differs from what the Operator last reviewed.
  final bool impactChanged;
  final Failure? failure;
  final EmergencyOperationResult? result;

  bool get isPasswordRejected => switch (failure) {
    EmergencyTourFailure(reason: EmergencyTourFailureReason.wrongPassword) =>
      true,
    _ => false,
  };

  @override
  List<Object?> get props => [
    stage,
    impact,
    blockReason,
    pendingDecision,
    impactChanged,
    failure,
    result,
  ];
}
