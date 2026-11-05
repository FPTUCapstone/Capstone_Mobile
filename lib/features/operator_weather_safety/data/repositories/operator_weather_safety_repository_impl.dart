import 'package:dio/dio.dart';
import 'package:trip_mate_mobile/core/error/error_mapper.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/data/datasources/operator_weather_safety_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/emergency_decision.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_repository.dart';

final class OperatorWeatherSafetyRepositoryImpl
    implements OperatorWeatherSafetyRepository {
  const OperatorWeatherSafetyRepositoryImpl(this._remote);

  final OperatorWeatherSafetyRemoteDataSource _remote;

  static const _reasons = <String, EmergencyTourFailureReason>{
    'tour_schedule.concurrent_state_changed':
        EmergencyTourFailureReason.staleImpact,
    'tour_schedule.already_terminal': EmergencyTourFailureReason.terminal,
    'tour_schedule.already_completed': EmergencyTourFailureReason.completed,
    'tour_schedule.emergency_action_window_invalid':
        EmergencyTourFailureReason.wrongActionWindow,
    'tour_schedule.idempotency_payload_mismatch':
        EmergencyTourFailureReason.idempotencyMismatch,
    'trip_session.link_unverified':
        EmergencyTourFailureReason.unverifiedSessions,
    'user.password_invalid': EmergencyTourFailureReason.wrongPassword,
    'weather_safety_review.already_closed':
        EmergencyTourFailureReason.reviewClosed,
    'tour_schedule.emergency_evidence_stale':
        EmergencyTourFailureReason.staleEvidence,
  };

  static const _messages = <EmergencyTourFailureReason, String>{
    EmergencyTourFailureReason.staleImpact:
        'Tác động đã thay đổi. Vui lòng xem lại tác động mới nhất trước khi xác nhận.',
    EmergencyTourFailureReason.terminal:
        'Lịch khởi hành này đã có quyết định cuối cùng.',
    EmergencyTourFailureReason.completed:
        'Lịch khởi hành đã hoàn thành nên không thể hủy hoặc dừng.',
    EmergencyTourFailureReason.wrongActionWindow:
        'Thao tác này không còn phù hợp với thời gian khởi hành. Vui lòng xem lại tác động mới nhất.',
    EmergencyTourFailureReason.idempotencyMismatch:
        'Yêu cầu này trùng với một yêu cầu trước đó nhưng khác nội dung. Vui lòng xem lại tác động mới nhất.',
    EmergencyTourFailureReason.unverifiedSessions:
        'Có phiên đi tour chưa được xác minh nên không thể thực hiện thao tác này.',
    EmergencyTourFailureReason.wrongPassword:
        'Không xác minh được mật khẩu. Vui lòng thử lại.',
    EmergencyTourFailureReason.reviewClosed:
        'Hồ sơ cảnh báo đã đóng nên không thể xác nhận.',
    EmergencyTourFailureReason.staleEvidence:
        'Bằng chứng vừa được thay đổi. Vui lòng xem lại nội dung mới nhất trước khi lưu.',
  };

  static Failure _toFailure(Object error) {
    if (error is DioException) {
      final reason =
          _reasons[ErrorMapper.extractErrorCode(error.response?.data)];
      final message = _messages[reason];
      if (reason != null && message != null) {
        return EmergencyTourFailure(message, reason: reason);
      }
    }
    return ErrorMapper.toFailure(error);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error) {
      throw _toFailure(error);
    }
  }

  @override
  Future<List<WeatherSafetyReview>> getReviews() => _guard(_remote.getReviews);

  @override
  Future<WeatherSafetyReview> getReview(int reviewId) =>
      _guard(() => _remote.getReview(reviewId));

  @override
  Future<WeatherSafetyReview> acknowledgeReview(
    int reviewId, {
    String? immediateInstructions,
  }) =>
      _guard(() => _remote.acknowledgeReview(reviewId, immediateInstructions));

  @override
  Future<EmergencyImpact> getImpact({
    required int tourId,
    required int scheduleId,
  }) => _guard(() => _remote.getImpact(tourId, scheduleId));

  @override
  Future<EmergencyOperationResult> cancelBeforeDeparture(
    CancelBeforeDepartureDecision decision, {
    required String idempotencyKey,
  }) => _guard(() => _remote.cancelBeforeDeparture(decision, idempotencyKey));

  @override
  Future<EmergencyOperationResult> emergencyStop(
    EmergencyStopDecision decision, {
    required String currentPassword,
    required String idempotencyKey,
  }) => _guard(
    () => _remote.emergencyStop(decision, currentPassword, idempotencyKey),
  );

  @override
  Future<EmergencyEvidenceResult> saveEvidence({
    required int tourId,
    required int scheduleId,
    required EmergencyEvidence evidence,
    String? expectedVersion,
  }) => _guard(
    () => _remote.putEvidence(
      tourId,
      scheduleId,
      evidence,
      withdraw: false,
      expectedVersion: expectedVersion,
    ),
  );

  @override
  Future<EmergencyEvidenceSnapshot> getEvidence({
    required int tourId,
    required int scheduleId,
  }) => _guard(() => _remote.getEvidence(tourId, scheduleId));

  @override
  Future<EmergencyEvidenceResult> withdrawEvidence({
    required int tourId,
    required int scheduleId,
    String? expectedVersion,
  }) => _guard(
    () => _remote.putEvidence(
      tourId,
      scheduleId,
      null,
      withdraw: true,
      expectedVersion: expectedVersion,
    ),
  );
}
