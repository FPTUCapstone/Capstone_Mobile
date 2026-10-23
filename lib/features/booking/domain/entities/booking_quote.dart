import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/participant_type.dart';

/// One line of POST .../tour-bookings/quote's priceBreakdown. BR-63: the app never computes
/// unitPrice or lineAmount itself — every value here is read verbatim from the response.
final class QuotePriceLine extends Equatable {
  const QuotePriceLine({
    required this.participantType,
    required this.quantity,
    required this.unitPrice,
    required this.lineAmount,
  });

  final ParticipantType participantType;
  final int quantity;
  final int unitPrice;
  final int lineAmount;

  @override
  List<Object?> get props => [participantType, quantity, unitPrice, lineAmount];
}

/// Read-only response from POST /api/v1/traveler/tour-bookings/quote (UC-27 spec §3). Creates
/// nothing and reserves no capacity; price and availability are re-checked again on create.
final class BookingQuote extends Equatable {
  const BookingQuote({
    required this.tourId,
    required this.tourScheduleId,
    required this.currency,
    required this.participantCounts,
    required this.priceBreakdown,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.remainingSlots,
    this.appliedVoucherCode,
  });

  final String tourId;
  final String tourScheduleId;
  final String currency;
  final ParticipantCounts participantCounts;
  final List<QuotePriceLine> priceBreakdown;
  final int subtotalAmount;
  final int discountAmount;
  final int totalAmount;
  final int remainingSlots;
  final String? appliedVoucherCode;

  QuotePriceLine? lineFor(ParticipantType type) {
    for (final line in priceBreakdown) {
      if (line.participantType == type) return line;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    tourId,
    tourScheduleId,
    currency,
    participantCounts,
    priceBreakdown,
    subtotalAmount,
    discountAmount,
    totalAmount,
    remainingSlots,
    appliedVoucherCode,
  ];
}

/// Created-booking response from POST /api/v1/traveler/tour-bookings (UC-27 spec §4). UC-27
/// ends here; payment (UC-28) is a separate, user-initiated step this entity never triggers.
final class TourBooking extends Equatable {
  const TourBooking({
    required this.bookingId,
    required this.bookingCode,
    required this.status,
    required this.tourScheduleId,
    required this.currency,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.paymentExpiresAt,
    required this.createdAt,
  });

  final String bookingId;
  final String bookingCode;
  final String status;
  final String tourScheduleId;
  final String currency;
  final int subtotalAmount;
  final int discountAmount;
  final int totalAmount;
  final DateTime paymentExpiresAt;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    bookingId,
    bookingCode,
    status,
    tourScheduleId,
    currency,
    subtotalAmount,
    discountAmount,
    totalAmount,
    paymentExpiresAt,
    createdAt,
  ];
}
