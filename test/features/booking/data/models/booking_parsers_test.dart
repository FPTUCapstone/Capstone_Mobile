import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/booking/data/models/booking_parsers.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/participant_type.dart';

void main() {
  group('parseBookingQuote', () {
    test('parses the full quote response including appliedVoucher', () {
      final quote = parseBookingQuote({
        'tourId': '45',
        'tourScheduleId': '123',
        'currency': 'VND',
        'participantCounts': {'adult': 1, 'child': 1, 'infant': 0},
        'priceBreakdown': [
          {
            'participantType': 'Adult',
            'quantity': 1,
            'unitPrice': 1000000,
            'lineAmount': 1000000,
          },
          {
            'participantType': 'Child',
            'quantity': 1,
            'unitPrice': 700000,
            'lineAmount': 700000,
          },
        ],
        'subtotalAmount': 1700000,
        'discountAmount': 200000,
        'totalAmount': 1500000,
        'remainingSlots': 5,
        'appliedVoucher': {'code': 'SUMMER2026'},
      });

      expect(quote.tourId, '45');
      expect(quote.totalAmount, 1500000);
      expect(quote.appliedVoucherCode, 'SUMMER2026');
      expect(quote.lineFor(ParticipantType.child)?.unitPrice, 700000);
    });

    test('treats a null appliedVoucher as no voucher applied', () {
      final quote = parseBookingQuote({
        'tourId': '45',
        'tourScheduleId': '123',
        'currency': 'VND',
        'participantCounts': {'adult': 1, 'child': 0, 'infant': 0},
        'priceBreakdown': <Object?>[],
        'subtotalAmount': 1000000,
        'discountAmount': 0,
        'totalAmount': 1000000,
        'remainingSlots': 5,
        'appliedVoucher': null,
      });

      expect(quote.appliedVoucherCode, isNull);
    });

    test('rejects a non-object payload', () {
      expect(() => parseBookingQuote('not an object'), throwsFormatException);
    });
  });

  group('parseTourBooking', () {
    test('parses the create-booking response', () {
      final booking = parseTourBooking({
        'bookingId': '456',
        'bookingCode': 'BK-20261017-00001',
        'status': 'PendingPayment',
        'tourScheduleId': '123',
        'currency': 'VND',
        'subtotalAmount': 2000000,
        'discountAmount': 200000,
        'totalAmount': 1800000,
        'paymentExpiresAt': '2026-10-17T10:30:00Z',
        'createdAt': '2026-10-17T10:15:00Z',
      });

      expect(booking.bookingId, '456');
      expect(booking.status, 'PendingPayment');
      expect(booking.paymentExpiresAt, DateTime.utc(2026, 10, 17, 10, 30));
    });

    test('rejects a payload missing a required field', () {
      expect(
        () => parseTourBooking({'bookingId': '456'}),
        throwsFormatException,
      );
    });
  });
}
