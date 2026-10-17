import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_quote.dart';

abstract interface class BookingRepository {
  /// POST .../tour-bookings/quote — read-only, creates nothing and reserves no capacity.
  Future<BookingQuote> quote({
    required String tourScheduleId,
    required ParticipantCounts participantCounts,
    String? voucherCode,
  });

  /// POST .../tour-bookings — atomic, idempotent create. [idempotencyKey] must be the same
  /// value across a retry of the same submission intent, and a new one for any edited intent.
  Future<TourBooking> createBooking({
    required String tourScheduleId,
    required List<BookingParticipant> participants,
    required String idempotencyKey,
    String? voucherCode,
  });
}
