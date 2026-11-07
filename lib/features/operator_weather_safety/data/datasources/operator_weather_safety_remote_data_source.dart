import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/data/models/operator_weather_safety_json.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';

abstract interface class OperatorWeatherSafetyRemoteDataSource {
  Future<List<WeatherSafetyReview>> getReviews();

  Future<WeatherSafetyReview> getReview(int reviewId);

  Future<WeatherSafetyReview> acknowledgeReview(
    int reviewId,
    String? immediateInstructions,
  );

  Future<EmergencyImpact> getImpact(int tourId, int scheduleId);

  Future<EmergencyOperationResult> cancelBeforeDeparture(
    CancelBeforeDepartureDecision decision,
    String idempotencyKey,
  );

  Future<EmergencyOperationResult> emergencyStop(
    EmergencyStopDecision decision,
    String currentPassword,
    String idempotencyKey,
  );

  Future<EmergencyEvidenceSnapshot> getEvidence(int tourId, int scheduleId);

  Future<EmergencyEvidenceResult> putEvidence(
    int tourId,
    int scheduleId,
    EmergencyEvidence? evidence, {
    required bool withdraw,
    String? expectedVersion,
  });
}

final class DioOperatorWeatherSafetyRemoteDataSource
    implements OperatorWeatherSafetyRemoteDataSource {
  DioOperatorWeatherSafetyRemoteDataSource(DioClient client)
    : _dio = client.dio;

  static const _reviewsPath = '/api/v1/operator/weather-safety-reviews';

  final Dio _dio;

  static String _schedulePath(int tourId, int scheduleId) =>
      '/api/v1/operator/tours/$tourId/schedules/$scheduleId';

  @override
  Future<List<WeatherSafetyReview>> getReviews() async {
    final response = await _dio.get<Object?>(_reviewsPath);
    return OperatorWeatherSafetyJson.reviews(response.data);
  }

  @override
  Future<WeatherSafetyReview> getReview(int reviewId) async {
    final response = await _dio.get<Object?>('$_reviewsPath/$reviewId');
    return OperatorWeatherSafetyJson.review(response.data);
  }

  @override
  Future<WeatherSafetyReview> acknowledgeReview(
    int reviewId,
    String? immediateInstructions,
  ) async {
    final response = await _dio.post<Object?>(
      '$_reviewsPath/$reviewId/acknowledge',
      data: {'immediateInstructions': immediateInstructions},
    );
    return OperatorWeatherSafetyJson.review(response.data);
  }

  @override
  Future<EmergencyImpact> getImpact(int tourId, int scheduleId) async {
    final response = await _dio.get<Object?>(
      '${_schedulePath(tourId, scheduleId)}/emergency-impact',
    );
    return OperatorWeatherSafetyJson.impact(response.data);
  }

  @override
  Future<EmergencyOperationResult> cancelBeforeDeparture(
    CancelBeforeDepartureDecision decision,
    String idempotencyKey,
  ) async {
    final response = await _dio.post<Object?>(
      '${_schedulePath(decision.tourId, decision.scheduleId)}/cancel-before-departure',
      data: OperatorWeatherSafetyJson.cancelBody(decision),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return OperatorWeatherSafetyJson.operationResult(response.data);
  }

  @override
  Future<EmergencyOperationResult> emergencyStop(
    EmergencyStopDecision decision,
    String currentPassword,
    String idempotencyKey,
  ) async {
    final response = await _dio.post<Object?>(
      '${_schedulePath(decision.tourId, decision.scheduleId)}/emergency-stop',
      data: OperatorWeatherSafetyJson.stopBody(decision, currentPassword),
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return OperatorWeatherSafetyJson.operationResult(response.data);
  }

  @override
  Future<EmergencyEvidenceSnapshot> getEvidence(
    int tourId,
    int scheduleId,
  ) async {
    final response = await _dio.get<Object?>(
      '${_schedulePath(tourId, scheduleId)}/emergency-evidence',
    );
    return OperatorWeatherSafetyJson.evidenceSnapshot(response.data);
  }

  @override
  Future<EmergencyEvidenceResult> putEvidence(
    int tourId,
    int scheduleId,
    EmergencyEvidence? evidence, {
    required bool withdraw,
    String? expectedVersion,
  }) async {
    final response = await _dio.put<Object?>(
      '${_schedulePath(tourId, scheduleId)}/emergency-evidence',
      data: OperatorWeatherSafetyJson.evidenceBody(
        evidence,
        withdraw: withdraw,
        expectedVersion: expectedVersion,
      ),
    );
    return OperatorWeatherSafetyJson.evidenceResult(response.data);
  }
}
