import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';

/// Parses the Backend UC-70 Operator payloads. Decision-critical fields fail
/// with [FormatException]; weather detail may legitimately be absent.
abstract final class OperatorWeatherSafetyJson {
  static final _impactVersion = RegExp(r'^[0-9a-fA-F]{64}$');

  static WeatherSafetyReview review(Object? raw) {
    final json = _map(raw);
    return WeatherSafetyReview(
      id: _requiredId(json['id']),
      tourScheduleId: _requiredId(json['tourScheduleId']),
      tourId: _requiredId(json['tourId']),
      tourTitle: _requiredText(json['tourTitle']),
      scheduleStartAtUtc: _requiredDate(json['scheduleStartAtUtc']),
      scheduleEndAtUtc: _requiredDate(json['scheduleEndAtUtc']),
      scheduleStatus: _requiredText(json['scheduleStatus']),
      status: _reviewStatus(_requiredText(json['status'])),
      urgentNoticeSentAtUtc: _requiredDate(json['urgentNoticeSentAtUtc']),
      acknowledgementDeadlineUtc: _requiredDate(
        json['acknowledgementDeadlineUtc'],
      ),
      isWithdrawn: json['isWithdrawn'] == true,
      eventType: _text(json['eventType']),
      severity: _text(json['severity']),
      description: _text(json['description']),
      validFromUtc: _date(json['validFromUtc']),
      validToUtc: _date(json['validToUtc']),
      originalAuthority: _text(json['originalAuthority']),
      officialRiskLevel: _int(json['officialVietnamRiskLevel']),
      verifiedDirective: _text(json['verifiedDirective']),
      affectedAreaSummary: _text(json['affectedAreaSummary']),
      acknowledgedAtUtc: _date(json['acknowledgedAtUtc']),
      escalatedAtUtc: _date(json['escalatedAtUtc']),
      escalationContact: _text(json['escalationContact']),
      immediateInstructions: _text(json['immediateInstructions']),
    );
  }

  static List<WeatherSafetyReview> reviews(Object? raw) {
    if (raw is! List) {
      throw const FormatException('Invalid weather safety review list.');
    }
    return raw.map(review).toList(growable: false);
  }

  static EmergencyImpact impact(Object? raw) {
    final json = _map(raw);
    final version = json['impactVersion'];
    final unverified = json['hasUnverifiedSessions'];
    if (version is! String ||
        !_impactVersion.hasMatch(version) ||
        unverified is! bool) {
      throw const FormatException('Invalid emergency impact.');
    }
    return EmergencyImpact(
      tourId: _requiredId(json['tourId']),
      scheduleId: _requiredId(json['scheduleId']),
      action: EmergencyAction.fromWire(json['action']),
      scheduleStatus: _requiredText(json['scheduleStatus']),
      paidBookingCount: _requiredCount(json['paidBookingCount']),
      unpaidBookingCount: _requiredCount(json['unpaidBookingCount']),
      totalPassengerCount: _requiredCount(json['totalPassengerCount']),
      activeSessionCount: _requiredCount(json['activeSessionCount']),
      unusedTicketCount: _requiredCount(json['unusedTicketCount']),
      hasUnverifiedSessions: unverified,
      impactVersion: version,
    );
  }

  static EmergencyOperationResult operationResult(Object? raw) {
    final json = _map(raw);
    return EmergencyOperationResult(
      operationId: _requiredId(json['operationId']),
      tourScheduleId: _requiredId(json['tourScheduleId']),
      action: EmergencyAction.fromWire(json['action']),
      scheduleStatus: _requiredText(json['scheduleStatus']),
      affectedBookingCount: _requiredCount(json['affectedBookingCount']),
      committedAtUtc: _requiredDate(json['committedAtUtc']),
    );
  }

  static EmergencyEvidenceResult evidenceResult(Object? raw) {
    final json = _map(raw);
    return EmergencyEvidenceResult(
      operationId: _requiredId(json['operationId']),
      evidenceAddedLater: json['evidenceAddedLater'] == true,
      updatedAtUtc: _requiredDate(json['updatedAtUtc']),
    );
  }

  static EmergencyEvidenceSnapshot evidenceSnapshot(Object? raw) {
    final json = _map(raw);
    return EmergencyEvidenceSnapshot(
      evidence: EmergencyEvidence(
        url: _text(json['evidenceUrl']),
        authorityReference: _text(json['authorityReference']),
        reference: _text(json['evidenceReference']),
      ),
      version: _requiredText(json['evidenceVersion']),
    );
  }

  static Map<String, dynamic> cancelBody(
    CancelBeforeDepartureDecision decision,
  ) => {
    'impactVersion': decision.impactVersion,
    'reason': decision.reason.wire,
    'reasonDetails': decision.reasonDetails,
    'emergencyContact': decision.emergencyContact,
    ..._evidenceFields(decision.evidence),
  };

  static Map<String, dynamic> stopBody(
    EmergencyStopDecision decision,
    String currentPassword,
  ) => {
    'impactVersion': decision.impactVersion,
    'currentPassword': currentPassword,
    'reason': decision.reason.wire,
    'reasonDetails': decision.reasonDetails,
    'immediateInstructions': decision.immediateInstructions,
    'emergencyContact': decision.emergencyContact,
    ..._evidenceFields(decision.evidence),
  };

  static Map<String, dynamic> evidenceBody(
    EmergencyEvidence? evidence, {
    required bool withdraw,
    String? expectedVersion,
  }) => {
    'evidenceUrl': evidence?.url,
    'authorityReference': evidence?.authorityReference,
    'evidenceReference': evidence?.reference,
    'withdrawEvidence': withdraw,
    'expectedVersion': expectedVersion,
  };

  static Map<String, dynamic> _evidenceFields(EmergencyEvidence evidence) => {
    'evidenceReference': evidence.reference,
    'evidenceUrl': evidence.url,
    'authorityReference': evidence.authorityReference,
    'addEvidenceLater': evidence.addLater,
  };

  static WeatherSafetyReviewStatus _reviewStatus(String value) =>
      switch (value) {
        'PendingAcknowledgement' =>
          WeatherSafetyReviewStatus.pendingAcknowledgement,
        'Escalated' => WeatherSafetyReviewStatus.escalated,
        'Acknowledged' => WeatherSafetyReviewStatus.acknowledged,
        'Closed' => WeatherSafetyReviewStatus.closed,
        _ => WeatherSafetyReviewStatus.unknown,
      };

  static Map<String, dynamic> _map(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    throw const FormatException('Invalid emergency response.');
  }

  static int _requiredId(Object? value) {
    if (value is int && value > 0) return value;
    throw const FormatException('Invalid emergency identifier.');
  }

  static int _requiredCount(Object? value) {
    if (value is int && value >= 0) return value;
    throw const FormatException('Invalid emergency count.');
  }

  static String _requiredText(Object? value) {
    final text = _text(value);
    if (text != null) return text;
    throw const FormatException('Invalid emergency text.');
  }

  static DateTime _requiredDate(Object? value) {
    final date = _date(value);
    if (date != null) return date;
    throw const FormatException('Invalid emergency date.');
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) => value is int ? value : null;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
