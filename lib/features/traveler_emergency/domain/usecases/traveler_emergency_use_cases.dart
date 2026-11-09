import 'package:trip_mate_mobile/features/traveler_emergency/domain/entities/traveler_emergency_status.dart';
import 'package:trip_mate_mobile/features/traveler_emergency/domain/repositories/traveler_emergency_repository.dart';

final class GetTravelerEmergencyNoticesUseCase {
  const GetTravelerEmergencyNoticesUseCase(this._repository);

  final TravelerEmergencyRepository _repository;

  Future<List<TravelerEmergencyNotice>> call() => _repository.getNotices();
}

final class GetTravelerEmergencyStatusUseCase {
  const GetTravelerEmergencyStatusUseCase(this._repository);

  final TravelerEmergencyRepository _repository;

  Future<TravelerEmergencyStatus> call(int bookingId) =>
      _repository.getStatus(bookingId);
}

final class AcknowledgeTravelerEmergencyStatusUseCase {
  const AcknowledgeTravelerEmergencyStatusUseCase(this._repository);

  final TravelerEmergencyRepository _repository;

  Future<DateTime> call(int bookingId) => _repository.acknowledge(bookingId);
}
