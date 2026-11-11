import 'package:trip_mate_mobile/features/booking_cancellation/domain/repositories/booking_cancellation_repository.dart';

final class CancelBookingUseCase {
  const CancelBookingUseCase(this._repository);
  final BookingCancellationRepository _repository;

  Future<void> call(
    int bookingId, {
    String? reasonCategory,
    String? reasonDetail,
    required bool confirmed,
    required String idempotencyKey,
  }) => _repository.cancel(
    bookingId,
    reasonCategory: reasonCategory,
    reasonDetail: reasonDetail,
    confirmed: confirmed,
    idempotencyKey: idempotencyKey,
  );
}
