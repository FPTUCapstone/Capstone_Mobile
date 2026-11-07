import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_repository.dart';

final class GetWeatherSafetyReviewsUseCase {
  const GetWeatherSafetyReviewsUseCase(this._repository);

  final OperatorWeatherSafetyRepository _repository;

  Future<List<WeatherSafetyReview>> call() => _repository.getReviews();
}

final class GetWeatherSafetyReviewUseCase {
  const GetWeatherSafetyReviewUseCase(this._repository);

  final OperatorWeatherSafetyRepository _repository;

  Future<WeatherSafetyReview> call(int reviewId) =>
      _repository.getReview(reviewId);
}

final class AcknowledgeWeatherSafetyReviewUseCase {
  const AcknowledgeWeatherSafetyReviewUseCase(this._repository);

  final OperatorWeatherSafetyRepository _repository;

  Future<WeatherSafetyReview> call(
    int reviewId, {
    String? immediateInstructions,
  }) => _repository.acknowledgeReview(
    reviewId,
    immediateInstructions: immediateInstructions,
  );
}

final class GetEmergencyImpactUseCase {
  const GetEmergencyImpactUseCase(this._repository);

  final OperatorWeatherSafetyRepository _repository;

  Future<EmergencyImpact> call({
    required int tourId,
    required int scheduleId,
  }) => _repository.getImpact(tourId: tourId, scheduleId: scheduleId);
}

final class CancelBeforeDepartureUseCase {
  const CancelBeforeDepartureUseCase(this._repository);

  final OperatorWeatherSafetyRepository _repository;

  Future<EmergencyOperationResult> call(
    CancelBeforeDepartureDecision decision, {
    required String idempotencyKey,
  }) => _repository.cancelBeforeDeparture(
    decision,
    idempotencyKey: idempotencyKey,
  );
}

final class EmergencyStopTourUseCase {
  const EmergencyStopTourUseCase(this._repository);

  final OperatorWeatherSafetyRepository _repository;

  Future<EmergencyOperationResult> call(
    EmergencyStopDecision decision, {
    required String currentPassword,
    required String idempotencyKey,
  }) => _repository.emergencyStop(
    decision,
    currentPassword: currentPassword,
    idempotencyKey: idempotencyKey,
  );
}

final class GetEmergencyEvidenceUseCase {
  const GetEmergencyEvidenceUseCase(this._repository);

  final OperatorWeatherSafetyRepository _repository;

  Future<EmergencyEvidenceSnapshot> call({
    required int tourId,
    required int scheduleId,
  }) => _repository.getEvidence(tourId: tourId, scheduleId: scheduleId);
}

final class SaveEmergencyEvidenceUseCase {
  const SaveEmergencyEvidenceUseCase(this._repository);

  final OperatorWeatherSafetyRepository _repository;

  Future<EmergencyEvidenceResult> call({
    required int tourId,
    required int scheduleId,
    required EmergencyEvidence evidence,
    String? expectedVersion,
  }) => _repository.saveEvidence(
    tourId: tourId,
    scheduleId: scheduleId,
    evidence: evidence,
    expectedVersion: expectedVersion,
  );
}

final class WithdrawEmergencyEvidenceUseCase {
  const WithdrawEmergencyEvidenceUseCase(this._repository);

  final OperatorWeatherSafetyRepository _repository;

  Future<EmergencyEvidenceResult> call({
    required int tourId,
    required int scheduleId,
    String? expectedVersion,
  }) => _repository.withdrawEvidence(
    tourId: tourId,
    scheduleId: scheduleId,
    expectedVersion: expectedVersion,
  );
}
