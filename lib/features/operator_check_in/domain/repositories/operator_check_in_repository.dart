import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';

abstract interface class OperatorCheckInRepository {
  Future<List<OperatorDepartureSummary>> getTodayDepartures({DateTime? targetDate});

  Future<DepartureProgress> getDepartureProgress(int scheduleId);

  Future<CheckInResult> scanCheckIn({
    required int scheduleId,
    String? qrContent,
    String? bookingCode,
    double? latitude,
    double? longitude,
  });
}
