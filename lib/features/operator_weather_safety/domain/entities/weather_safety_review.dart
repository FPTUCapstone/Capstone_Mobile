import 'package:equatable/equatable.dart';

enum WeatherSafetyReviewStatus {
  pendingAcknowledgement,
  escalated,
  acknowledged,
  closed,
  unknown,
}

/// An Operator-owned review of a weather event. It never cancels or stops a tour.
final class WeatherSafetyReview extends Equatable {
  const WeatherSafetyReview({
    required this.id,
    required this.tourScheduleId,
    required this.tourId,
    required this.tourTitle,
    required this.scheduleStartAtUtc,
    required this.scheduleEndAtUtc,
    required this.scheduleStatus,
    required this.status,
    required this.urgentNoticeSentAtUtc,
    required this.acknowledgementDeadlineUtc,
    required this.isWithdrawn,
    this.eventType,
    this.severity,
    this.description,
    this.validFromUtc,
    this.validToUtc,
    this.originalAuthority,
    this.officialRiskLevel,
    this.verifiedDirective,
    this.affectedAreaSummary,
    this.acknowledgedAtUtc,
    this.escalatedAtUtc,
    this.escalationContact,
    this.immediateInstructions,
  });

  final int id;
  final int tourScheduleId;
  final int tourId;
  final String tourTitle;
  final DateTime scheduleStartAtUtc;
  final DateTime scheduleEndAtUtc;

  /// Backend text (`Scheduled`, `Cancelled`, `Completed`, `EmergencyStopped`).
  final String scheduleStatus;
  final WeatherSafetyReviewStatus status;
  final DateTime urgentNoticeSentAtUtc;
  final DateTime acknowledgementDeadlineUtc;
  final bool isWithdrawn;
  final String? eventType;
  final String? severity;
  final String? description;
  final DateTime? validFromUtc;
  final DateTime? validToUtc;
  final String? originalAuthority;
  final int? officialRiskLevel;
  final String? verifiedDirective;
  final String? affectedAreaSummary;
  final DateTime? acknowledgedAtUtc;
  final DateTime? escalatedAtUtc;
  final String? escalationContact;
  final String? immediateInstructions;

  /// Drives the Safety Alerts badge.
  bool get needsAttention =>
      status == WeatherSafetyReviewStatus.pendingAcknowledgement ||
      status == WeatherSafetyReviewStatus.escalated;

  bool get canAcknowledge => needsAttention;

  bool get hasTerminalDecision =>
      scheduleStatus == 'Cancelled' || scheduleStatus == 'EmergencyStopped';

  @override
  List<Object?> get props => [
    id,
    tourScheduleId,
    tourId,
    tourTitle,
    scheduleStartAtUtc,
    scheduleEndAtUtc,
    scheduleStatus,
    status,
    urgentNoticeSentAtUtc,
    acknowledgementDeadlineUtc,
    isWithdrawn,
    eventType,
    severity,
    description,
    validFromUtc,
    validToUtc,
    originalAuthority,
    officialRiskLevel,
    verifiedDirective,
    affectedAreaSummary,
    acknowledgedAtUtc,
    escalatedAtUtc,
    escalationContact,
    immediateInstructions,
  ];
}
