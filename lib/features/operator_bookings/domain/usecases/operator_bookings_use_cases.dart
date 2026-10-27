import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/repositories/operator_bookings_repository.dart';

/// UC-40: one page of the operator's customer bookings.
final class ListOperatorBookingsUseCase {
  const ListOperatorBookingsUseCase(this._repository);

  final OperatorBookingsRepository _repository;

  Future<OperatorBookingsPage> call(OperatorBookingsQuery query) =>
      _repository.getPage(query);
}

/// UC-40: one booking with its passenger manifest.
final class GetOperatorBookingUseCase {
  const GetOperatorBookingUseCase(this._repository);

  final OperatorBookingsRepository _repository;

  Future<OperatorBookingDetail> call(String bookingId) =>
      _repository.getDetail(bookingId);
}

/// UC-40: the owned tours offered by the tour filter.
final class LoadOperatorBookingTourOptionsUseCase {
  const LoadOperatorBookingTourOptionsUseCase(this._repository);

  final OperatorBookingsRepository _repository;

  Future<List<OperatorBookingTourOption>> call() =>
      _repository.getTourOptions();
}
