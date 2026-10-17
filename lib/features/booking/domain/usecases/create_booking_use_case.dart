import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_quote.dart';
import 'package:trip_mate_mobile/features/booking/domain/repositories/booking_repository.dart';

final class CreateBookingUseCase {
  const CreateBookingUseCase(this._repository);
  final BookingRepository _repository;

  Future<TourBooking> call({
    required String tourScheduleId,
    required List<BookingParticipant> participants,
    required String idempotencyKey,
    String? voucherCode,
  }) => _repository.createBooking(
    tourScheduleId: tourScheduleId,
    participants: participants,
    idempotencyKey: idempotencyKey,
    voucherCode: voucherCode,
  );
}
