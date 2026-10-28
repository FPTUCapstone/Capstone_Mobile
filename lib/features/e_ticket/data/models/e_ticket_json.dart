import 'package:trip_mate_mobile/features/e_ticket/domain/entities/e_ticket.dart';

/// Strict mapping of the UC-29 ticket body to the domain entity.
///
/// Anything that does not match the contract throws a [FormatException]; the
/// repository turns that into a safe failure. Unknown properties are ignored.
abstract final class ETicketJson {
  static final _departureDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static ETicket ticket(Object? json) {
    final source = _map(json);
    final tour = _map(source['tour']);
    final schedule = _map(source['schedule']);
    final participants = _map(source['participants']);
    final validity = _map(source['validity']);
    if (!source.containsKey('qr')) _fail();
    final qr = source['qr'];

    return ETicket(
      ticketId: _id(source['ticketId']),
      ticketCode: _text(source['ticketCode']),
      bookingId: _id(source['bookingId']),
      bookingCode: _text(source['bookingCode']),
      status: status(source['ticketStatus']),
      tourId: _id(tour['tourId']),
      tourTitle: _text(tour['title']),
      operatorName: source['operatorName'] is String
          ? source['operatorName'] as String
          : _fail(),
      startAtUtc: _instant(schedule['startAtUtc']),
      endAtUtc: _instant(schedule['endAtUtc']),
      meetingPoint: _optionalText(schedule['meetingPoint']),
      participantCount: _int(source['participantCount'], min: 0),
      adults: _int(participants['adult'], min: 0),
      children: _int(participants['child'], min: 0),
      infants: _int(participants['infant'], min: 0),
      departureDate: _date(validity['departureDate']),
      validFromUtc: _instant(validity['validFromUtc']),
      validUntilUtc: _instant(validity['validUntilUtc']),
      checkedInAtUtc: _optionalInstant(source['checkedInAtUtc']),
      qr: qr == null ? null : _qr(qr),
    );
  }

  /// Wire value of `ticketStatus` (also sent with `ticket.not_refreshable`).
  static ETicketStatus status(Object? value) => switch (value) {
    'NotYetActive' => ETicketStatus.notYetActive,
    'Valid' => ETicketStatus.valid,
    'Used' => ETicketStatus.used,
    'Cancelled' => ETicketStatus.cancelled,
    'Expired' => ETicketStatus.expired,
    _ => _fail(),
  };

  static ETicketQr _qr(Object? value) {
    final source = _map(value);
    return ETicketQr(
      content: _text(source['content']),
      issuedAtUtc: _instant(source['issuedAtUtc']),
    );
  }

  static Never _fail() =>
      throw const FormatException('The e-ticket does not match the contract.');

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : _fail();

  static String _text(Object? value) =>
      value is String && value.isNotEmpty ? value : _fail();

  static String? _optionalText(Object? value) =>
      value == null ? null : _text(value);

  static int _int(Object? value, {required int min}) {
    if (value is! int || value < min) _fail();
    return value;
  }

  /// A positive identity. Dart ints are 64-bit on device, so the value is exact.
  static int _id(Object? value) => _int(value, min: 1);

  static DateTime _instant(Object? value) {
    final parsed = DateTime.tryParse(_text(value));
    return parsed == null ? _fail() : parsed.toUtc();
  }

  static DateTime? _optionalInstant(Object? value) =>
      value == null ? null : _instant(value);

  static DateTime _date(Object? value) {
    final text = _text(value);
    if (!_departureDate.hasMatch(text)) _fail();
    final parts = text.split('-').map(int.parse).toList(growable: false);
    return DateTime.utc(parts[0], parts[1], parts[2]);
  }
}
