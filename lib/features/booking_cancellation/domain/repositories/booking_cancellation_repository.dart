import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_preview.dart';

/// UC-41 cancellation preview and submission. Failures are thrown as `BookingCancellationFailure`.
abstract interface class BookingCancellationRepository {
  Future<BookingCancellationPreview> getPreview(int bookingId);

  Future<void> cancel(
    int bookingId, {
    String? reasonCategory,
    String? reasonDetail,
    required bool confirmed,
    required String idempotencyKey,
  });
}
