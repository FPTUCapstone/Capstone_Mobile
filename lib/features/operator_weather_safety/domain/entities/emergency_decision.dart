import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';

/// Fresh Backend projection shown before a terminal decision.
final class EmergencyImpact extends Equatable {
  const EmergencyImpact({
    required this.tourId,
    required this.scheduleId,
    required this.action,
    required this.scheduleStatus,
    required this.paidBookingCount,
    required this.unpaidBookingCount,
    required this.totalPassengerCount,
    required this.activeSessionCount,
    required this.unusedTicketCount,
    required this.hasUnverifiedSessions,
    required this.impactVersion,
  });

  final int tourId;
  final int scheduleId;
  final EmergencyAction action;
  final String scheduleStatus;
  final int paidBookingCount;
  final int unpaidBookingCount;
  final int totalPassengerCount;
  final int activeSessionCount;
  final int unusedTicketCount;
  final bool hasUnverifiedSessions;
  final String impactVersion;

  @override
  List<Object?> get props => [
    tourId,
    scheduleId,
    action,
    scheduleStatus,
    paidBookingCount,
    unpaidBookingCount,
    totalPassengerCount,
    activeSessionCount,
    unusedTicketCount,
    hasUnverifiedSessions,
    impactVersion,
  ];
}

enum EmergencyReason {
  weatherEmergency('WeatherEmergency', 'Weather emergency'),
  authorityDirective('AuthorityDirective', 'Authority directive'),
  destinationUnavailable('DestinationUnavailable', 'Destination unavailable'),
  transportFailure('TransportFailure', 'Transport failure'),
  safetyIncident('SafetyIncident', 'Safety incident'),
  other('Other', 'Other');

  const EmergencyReason(this.wire, this.label);

  final String wire;
  final String label;
}

/// Operator-supplied evidence: an HTTPS link and/or reference text, never a file.
final class EmergencyEvidence extends Equatable {
  const EmergencyEvidence({
    this.url,
    this.authorityReference,
    this.reference,
    this.addLater = false,
  });

  static const urlMaxLength = 1000;
  static const authorityReferenceMaxLength = 200;
  static const referenceMaxLength = 500;

  final String? url;
  final String? authorityReference;
  final String? reference;

  /// The Operator will supply the evidence after the terminal decision.
  final bool addLater;

  /// Mirrors the Backend rule: absolute HTTPS, no embedded credentials.
  static bool isAcceptableUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.length > urlMaxLength) return false;
    final uri = Uri.tryParse(trimmed);
    return uri != null &&
        uri.isScheme('https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  @override
  List<Object?> get props => [url, authorityReference, reference, addLater];
}

/// The saved evidence and the version a save must be based on.
final class EmergencyEvidenceSnapshot extends Equatable {
  const EmergencyEvidenceSnapshot({
    required this.evidence,
    required this.version,
  });

  final EmergencyEvidence evidence;
  final String version;

  @override
  List<Object?> get props => [evidence, version];
}

/// The stable payload of one terminal Operator intent. It deliberately has no
/// password: the password is a transient argument of the submit call only.
sealed class EmergencyDecision extends Equatable {
  const EmergencyDecision({
    required this.tourId,
    required this.scheduleId,
    required this.impactVersion,
    required this.reason,
    required this.reasonDetails,
    this.emergencyContact,
    this.evidence = const EmergencyEvidence(),
  });

  static const reasonDetailsMaxLength = 1000;
  static const instructionsMaxLength = 1000;
  static const contactMaxLength = 100;

  final int tourId;
  final int scheduleId;
  final String impactVersion;
  final EmergencyReason reason;
  final String reasonDetails;
  final String? emergencyContact;
  final EmergencyEvidence evidence;

  EmergencyDecision withImpactVersion(String version);

  @override
  List<Object?> get props => [
    tourId,
    scheduleId,
    impactVersion,
    reason,
    reasonDetails,
    emergencyContact,
    evidence,
  ];
}

final class CancelBeforeDepartureDecision extends EmergencyDecision {
  const CancelBeforeDepartureDecision({
    required super.tourId,
    required super.scheduleId,
    required super.impactVersion,
    required super.reason,
    required super.reasonDetails,
    super.emergencyContact,
    super.evidence,
  });

  @override
  CancelBeforeDepartureDecision withImpactVersion(String version) =>
      CancelBeforeDepartureDecision(
        tourId: tourId,
        scheduleId: scheduleId,
        impactVersion: version,
        reason: reason,
        reasonDetails: reasonDetails,
        emergencyContact: emergencyContact,
        evidence: evidence,
      );
}

final class EmergencyStopDecision extends EmergencyDecision {
  const EmergencyStopDecision({
    required super.tourId,
    required super.scheduleId,
    required super.impactVersion,
    required super.reason,
    required super.reasonDetails,
    required this.immediateInstructions,
    required String super.emergencyContact,
    super.evidence,
  });

  final String immediateInstructions;

  @override
  EmergencyStopDecision withImpactVersion(String version) =>
      EmergencyStopDecision(
        tourId: tourId,
        scheduleId: scheduleId,
        impactVersion: version,
        reason: reason,
        reasonDetails: reasonDetails,
        immediateInstructions: immediateInstructions,
        emergencyContact: emergencyContact!,
        evidence: evidence,
      );

  @override
  List<Object?> get props => [...super.props, immediateInstructions];
}

final class EmergencyOperationResult extends Equatable {
  const EmergencyOperationResult({
    required this.operationId,
    required this.tourScheduleId,
    required this.action,
    required this.scheduleStatus,
    required this.affectedBookingCount,
    required this.committedAtUtc,
  });

  final int operationId;
  final int tourScheduleId;
  final EmergencyAction action;
  final String scheduleStatus;
  final int affectedBookingCount;
  final DateTime committedAtUtc;

  @override
  List<Object?> get props => [
    operationId,
    tourScheduleId,
    action,
    scheduleStatus,
    affectedBookingCount,
    committedAtUtc,
  ];
}

final class EmergencyEvidenceResult extends Equatable {
  const EmergencyEvidenceResult({
    required this.operationId,
    required this.evidenceAddedLater,
    required this.updatedAtUtc,
  });

  final int operationId;
  final bool evidenceAddedLater;
  final DateTime updatedAtUtc;

  @override
  List<Object?> get props => [operationId, evidenceAddedLater, updatedAtUtc];
}
