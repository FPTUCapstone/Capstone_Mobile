import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/repositories/operator_check_in_repository.dart';

final class GetOperatorTodayDeparturesUseCase {
  const GetOperatorTodayDeparturesUseCase(this._repository);

  final OperatorCheckInRepository _repository;

  Future<List<OperatorDepartureSummary>> call({DateTime? targetDate}) =>
      _repository.getTodayDepartures(targetDate: targetDate);
}

final class GetDepartureProgressUseCase {
  const GetDepartureProgressUseCase(this._repository);

  final OperatorCheckInRepository _repository;

  Future<DepartureProgress> call(int scheduleId) =>
      _repository.getDepartureProgress(scheduleId);
}

final class ScanCheckInUseCase {
  const ScanCheckInUseCase(this._repository);

  final OperatorCheckInRepository _repository;

  Future<CheckInResult> call({
    required int scheduleId,
    String? qrContent,
    String? bookingCode,
    double? latitude,
    double? longitude,
  }) => _repository.scanCheckIn(
    scheduleId: scheduleId,
    qrContent: qrContent,
    bookingCode: bookingCode,
    latitude: latitude,
    longitude: longitude,
  );
}
