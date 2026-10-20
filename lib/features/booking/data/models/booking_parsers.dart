import 'package:trip_mate_mobile/features/booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/booking_quote.dart';
import 'package:trip_mate_mobile/features/booking/domain/entities/participant_type.dart';

/// Strict JSON parsing for the UC-27 Book Tour API. A malformed payload is a [FormatException],
/// never a half-filled entity, so the UI cannot show invented price or booking data.

Map<String, Object?> _object(Object? payload, String label) {
  if (payload is! Map) throw FormatException('$label must be an object.');
  return Map<String, Object?>.from(payload);
}

List<Map<String, Object?>> _objects(Object? payload, String label) {
  if (payload is! List) throw FormatException('$label must be a list.');
  return payload
      .map((value) {
        if (value is! Map) throw FormatException('$label item is invalid.');
        return Map<String, Object?>.from(value);
      })
      .toList(growable: false);
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key is missing.');
  return value.toInt();
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key is missing.');
  return value;
}

DateTime _date(Map<String, Object?> json, String key) {
  final parsed = DateTime.tryParse(_string(json, key));
  if (parsed == null) throw FormatException('$key is not a date.');
  return parsed.toUtc();
}

BookingQuote parseBookingQuote(Object? payload) {
  final json = _object(payload, 'Quote');
  final counts = _object(json['participantCounts'], 'participantCounts');
  return BookingQuote(
    tourId: _string(json, 'tourId'),
    tourScheduleId: _string(json, 'tourScheduleId'),
    currency: _string(json, 'currency'),
    participantCounts: ParticipantCounts(
      adult: _int(counts, 'adult'),
      child: _int(counts, 'child'),
      infant: _int(counts, 'infant'),
    ),
    priceBreakdown: _objects(json['priceBreakdown'], 'priceBreakdown')
        .map(
          (line) => QuotePriceLine(
            participantType: ParticipantType.fromWire(
              _string(line, 'participantType'),
            ),
            quantity: _int(line, 'quantity'),
            unitPrice: _int(line, 'unitPrice'),
            lineAmount: _int(line, 'lineAmount'),
          ),
        )
        .toList(growable: false),
    subtotalAmount: _int(json, 'subtotalAmount'),
    discountAmount: _int(json, 'discountAmount'),
    totalAmount: _int(json, 'totalAmount'),
    remainingSlots: _int(json, 'remainingSlots'),
    appliedVoucherCode: switch (json['appliedVoucher']) {
      final Map voucher =>
        voucher['code'] is String ? voucher['code'] as String : null,
      _ => null,
    },
  );
}

TourBooking parseTourBooking(Object? payload) {
  final json = _object(payload, 'Booking');
  return TourBooking(
    bookingId: _string(json, 'bookingId'),
    bookingCode: _string(json, 'bookingCode'),
    status: _string(json, 'status'),
    tourScheduleId: _string(json, 'tourScheduleId'),
    currency: _string(json, 'currency'),
    subtotalAmount: _int(json, 'subtotalAmount'),
    discountAmount: _int(json, 'discountAmount'),
    totalAmount: _int(json, 'totalAmount'),
    paymentExpiresAt: _date(json, 'paymentExpiresAt'),
    createdAt: _date(json, 'createdAt'),
  );
}
