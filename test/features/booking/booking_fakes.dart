import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_contact.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_quote.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/participant_type.dart';
import 'package:trip_mate_mobile/features/booking/domain/repositories/booking_repository.dart';

BookingQuote sampleQuote({
  ParticipantCounts counts = const ParticipantCounts(adult: 1),
  int unitPrice = 1000000,
  int discountAmount = 0,
  int remainingSlots = 5,
  String? appliedVoucherCode,
}) {
  final subtotal = counts.total * unitPrice;
  return BookingQuote(
    tourId: '45',
    tourScheduleId: '123',
    currency: 'VND',
    participantCounts: counts,
    priceBreakdown: [
      QuotePriceLine(
        participantType: ParticipantType.adult,
        quantity: counts.adult,
        unitPrice: unitPrice,
        lineAmount: counts.adult * unitPrice,
      ),
      QuotePriceLine(
        participantType: ParticipantType.child,
        quantity: counts.child,
        unitPrice: unitPrice,
        lineAmount: counts.child * unitPrice,
      ),
      QuotePriceLine(
        participantType: ParticipantType.infant,
        quantity: counts.infant,
        unitPrice: unitPrice,
        lineAmount: counts.infant * unitPrice,
      ),
    ],
    subtotalAmount: subtotal,
    discountAmount: discountAmount,
    totalAmount: subtotal - discountAmount,
    remainingSlots: remainingSlots,
    appliedVoucherCode: appliedVoucherCode,
  );
}

final class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({
    this.failQuotes = 0,
    this.failCreates = 0,
    this.failContactLookup = false,
    this.contact = const BookingContact(
      fullName: 'Nguyen Van A',
      phoneNumber: '0912345678',
      email: 'traveler@example.com',
    ),
  });

  int failQuotes;
  int failCreates;
  bool failContactLookup;
  BookingContact contact;
  final quoteCalls = <(String, ParticipantCounts, String?)>[];
  final createKeys = <String>[];
  final createCalls = <(String, List<BookingParticipant>, String?)>[];

  @override
  Future<BookingContact> getBookingContact() async {
    if (failContactLookup) throw const NetworkFailure();
    return contact;
  }

  @override
  Future<BookingQuote> quote({
    required String tourScheduleId,
    required ParticipantCounts participantCounts,
    String? voucherCode,
  }) async {
    quoteCalls.add((tourScheduleId, participantCounts, voucherCode));
    if (failQuotes > 0) {
      failQuotes -= 1;
      throw const NetworkFailure();
    }
    return sampleQuote(
      counts: participantCounts,
      appliedVoucherCode: voucherCode,
    );
  }

  @override
  Future<TourBooking> createBooking({
    required String tourScheduleId,
    required List<BookingParticipant> participants,
    required String idempotencyKey,
    String? voucherCode,
  }) async {
    createKeys.add(idempotencyKey);
    createCalls.add((tourScheduleId, participants, voucherCode));
    if (failCreates > 0) {
      failCreates -= 1;
      throw const NetworkFailure();
    }
    return TourBooking(
      bookingId: '456',
      bookingCode: 'BK-20261017-00001',
      status: 'PendingPayment',
      tourScheduleId: tourScheduleId,
      currency: 'VND',
      subtotalAmount: 1000000,
      discountAmount: 0,
      totalAmount: 1000000,
      paymentExpiresAt: DateTime.utc(2026, 10, 17, 10, 30),
      createdAt: DateTime.utc(2026, 10, 17, 10, 15),
    );
  }
}
