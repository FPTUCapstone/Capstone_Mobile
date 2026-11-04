import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';

abstract interface class OperatorWeatherSafetyRepository {
  /// Every owned review, newest first as ordered by the Backend.
  Future<List<WeatherSafetyReview>> getReviews();

  Future<WeatherSafetyReview> getReview(int reviewId);

  Future<WeatherSafetyReview> acknowledgeReview(
    int reviewId, {
    String? immediateInstructions,
  });

  Future<EmergencyImpact> getImpact({
    required int tourId,
    required int scheduleId,
  });

  Future<EmergencyOperationResult> cancelBeforeDeparture(
    CancelBeforeDepartureDecision decision, {
    required String idempotencyKey,
  });

  Future<EmergencyOperationResult> emergencyStop(
    EmergencyStopDecision decision, {
    required String currentPassword,
    required String idempotencyKey,
  });

  Future<EmergencyEvidenceSnapshot> getEvidence({
    required int tourId,
    required int scheduleId,
  });

  /// Replaces the whole evidence set, based on the version that was read.
  Future<EmergencyEvidenceResult> saveEvidence({
    required int tourId,
    required int scheduleId,
    required EmergencyEvidence evidence,
    String? expectedVersion,
  });

  Future<EmergencyEvidenceResult> withdrawEvidence({
    required int tourId,
    required int scheduleId,
    String? expectedVersion,
  });
}
