import 'package:trip_mate_mobile/features/booking_refund/domain/entities/booking_refund_progress.dart';

abstract interface class BookingRefundRepository {
  Future<BookingRefundProgress> getProgress(String bookingId);
}
