import 'dart:async';

import 'package:trip_mate_mobile/core/network/network_info.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_repository.dart';

import 'emergency_fixtures.dart';

WeatherSafetyReview review({
  int id = 7,
  WeatherSafetyReviewStatus status =
      WeatherSafetyReviewStatus.pendingAcknowledgement,
  String scheduleStatus = 'Scheduled',
  String? immediateInstructions,
}) => WeatherSafetyReview(
  id: id,
  tourScheduleId: 31,
  tourId: 12,
  tourTitle: 'Hue heritage day tour',
  scheduleStartAtUtc: DateTime.utc(2026, 11, 10, 1),
  scheduleEndAtUtc: DateTime.utc(2026, 11, 10, 10),
  scheduleStatus: scheduleStatus,
  status: status,
  urgentNoticeSentAtUtc: DateTime.utc(2026, 11, 9, 8),
  acknowledgementDeadlineUtc: DateTime.utc(2026, 11, 9, 9),
  isWithdrawn: false,
  eventType: 'Storm',
  severity: 'Severe',
  immediateInstructions: immediateInstructions,
);

EmergencyImpact impact({
  EmergencyAction action = EmergencyAction.cancelBeforeDeparture,
  String version = validImpactVersion,
  bool hasUnverifiedSessions = false,
}) => EmergencyImpact(
  tourId: 12,
  scheduleId: 31,
  action: action,
  scheduleStatus: 'Scheduled',
  paidBookingCount: 2,
  unpaidBookingCount: 1,
  totalPassengerCount: 5,
  activeSessionCount: 0,
  unusedTicketCount: 5,
  hasUnverifiedSessions: hasUnverifiedSessions,
  impactVersion: version,
);

final operationResult = EmergencyOperationResult(
  operationId: 90,
  tourScheduleId: 31,
  action: EmergencyAction.cancelBeforeDeparture,
  scheduleStatus: 'Cancelled',
  affectedBookingCount: 3,
  committedAtUtc: DateTime.utc(2026, 11, 10, 2),
);

final class FakeOperatorWeatherSafetyRepository
    implements OperatorWeatherSafetyRepository {
  List<WeatherSafetyReview> reviews = [];
  WeatherSafetyReview? reviewResult;
  WeatherSafetyReview? acknowledgeResult;
  final impacts = <Object>[];
  Object? failure;
  Object? acknowledgeFailure;
  Completer<void>? gate;

  int getReviewsCalls = 0;
  int getReviewCalls = 0;
  int acknowledgeCalls = 0;
  int impactCalls = 0;
  String? lastInstructions;
  final commands = <({EmergencyDecision decision, String key})>[];

  /// Queued outcomes for terminal commands: a Failure to throw, or a result.
  final commandOutcomes = <Object>[];
  final evidenceCalls = <EmergencyEvidence?>[];
  EmergencyEvidenceSnapshot currentEvidence = const EmergencyEvidenceSnapshot(
    evidence: EmergencyEvidence(),
    version: 'v0',
  );
  int evidenceReads = 0;
  String? lastExpectedVersion;
  Object? saveFailure;

  @override
  Future<EmergencyEvidenceSnapshot> getEvidence({
    required int tourId,
    required int scheduleId,
  }) async {
    evidenceReads++;
    await _pass();
    return currentEvidence;
  }

  Future<void> _pass() async {
    await gate?.future;
    final current = failure;
    if (current != null) throw current;
  }

  @override
  Future<List<WeatherSafetyReview>> getReviews() async {
    getReviewsCalls++;
    await _pass();
    return reviews;
  }

  @override
  Future<WeatherSafetyReview> getReview(int reviewId) async {
    getReviewCalls++;
    await _pass();
    return reviewResult!;
  }

  @override
  Future<WeatherSafetyReview> acknowledgeReview(
    int reviewId, {
    String? immediateInstructions,
  }) async {
    acknowledgeCalls++;
    lastInstructions = immediateInstructions;
    await _pass();
    final rejected = acknowledgeFailure;
    if (rejected != null) throw rejected;
    return acknowledgeResult!;
  }

  @override
  Future<EmergencyImpact> getImpact({
    required int tourId,
    required int scheduleId,
  }) async {
    impactCalls++;
    await gate?.future;
    final next = impacts.length > 1 ? impacts.removeAt(0) : impacts.single;
    if (next is EmergencyImpact) return next;
    throw next;
  }

  Future<EmergencyOperationResult> _command(
    EmergencyDecision decision,
    String key,
  ) async {
    commands.add((decision: decision, key: key));
    await gate?.future;
    final next = commandOutcomes.removeAt(0);
    if (next is EmergencyOperationResult) return next;
    throw next;
  }

  @override
  Future<EmergencyOperationResult> cancelBeforeDeparture(
    CancelBeforeDepartureDecision decision, {
    required String idempotencyKey,
  }) => _command(decision, idempotencyKey);

  @override
  Future<EmergencyOperationResult> emergencyStop(
    EmergencyStopDecision decision, {
    required String currentPassword,
    required String idempotencyKey,
  }) => _command(decision, idempotencyKey);

  final _evidenceResult = EmergencyEvidenceResult(
    operationId: 90,
    evidenceAddedLater: true,
    updatedAtUtc: DateTime.utc(2026, 11, 10, 3),
  );

  @override
  Future<EmergencyEvidenceResult> saveEvidence({
    required int tourId,
    required int scheduleId,
    required EmergencyEvidence evidence,
    String? expectedVersion,
  }) async {
    evidenceCalls.add(evidence);
    lastExpectedVersion = expectedVersion;
    await _pass();
    final rejected = saveFailure;
    if (rejected != null) throw rejected;
    return _evidenceResult;
  }

  @override
  Future<EmergencyEvidenceResult> withdrawEvidence({
    required int tourId,
    required int scheduleId,
    String? expectedVersion,
  }) async {
    evidenceCalls.add(null);
    lastExpectedVersion = expectedVersion;
    await _pass();
    return _evidenceResult;
  }
}

final class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({this.connected = true});

  bool connected;
  final _changes = StreamController<bool>.broadcast();

  void change(bool value) {
    connected = value;
    _changes.add(value);
  }

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onConnectivityChanged => _changes.stream;
}
