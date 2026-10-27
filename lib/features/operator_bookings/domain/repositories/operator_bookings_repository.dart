import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';

abstract interface class OperatorBookingsRepository {
  /// The signed-in Tour Operator's customer bookings (UC-40), filtered and paged by the backend.
  Future<OperatorBookingsPage> getPage(OperatorBookingsQuery query);

  /// One booking on a tour the operator owns; [bookingId] is a digit string.
  Future<OperatorBookingDetail> getDetail(String bookingId);

  /// The owned tours offered by the tour filter.
  Future<List<OperatorBookingTourOption>> getTourOptions();
}
