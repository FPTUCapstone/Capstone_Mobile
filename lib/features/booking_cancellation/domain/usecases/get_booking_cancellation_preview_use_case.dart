import 'package:trip_mate_mobile/features/booking_cancellation/domain/entities/booking_cancellation_preview.dart';
import 'package:trip_mate_mobile/features/booking_cancellation/domain/repositories/booking_cancellation_repository.dart';

final class GetBookingCancellationPreviewUseCase {
  const GetBookingCancellationPreviewUseCase(this._repository);
  final BookingCancellationRepository _repository;

  Future<BookingCancellationPreview> call(int bookingId) =>
      _repository.getPreview(bookingId);
}
