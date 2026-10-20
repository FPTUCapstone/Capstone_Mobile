import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_quote.dart';
import 'package:trip_mate_mobile/features/booking/domain/repositories/booking_repository.dart';

final class QuoteBookingUseCase {
  const QuoteBookingUseCase(this._repository);
  final BookingRepository _repository;

  Future<BookingQuote> call({
    required String tourScheduleId,
    required ParticipantCounts participantCounts,
    String? voucherCode,
  }) => _repository.quote(
    tourScheduleId: tourScheduleId,
    participantCounts: participantCounts,
    voucherCode: voucherCode,
  );
}
