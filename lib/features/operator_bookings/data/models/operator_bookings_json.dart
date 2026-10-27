import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';

/// Strict mapping of the UC-40 backend bodies (`Capstone_BE/docs/UC-40-api-contract.md`) to domain entities.
///
/// Anything that does not match the contract throws a [FormatException]; the repository turns that into a
/// safe failure. Entities are rebuilt field by field, so a property the contract says is never returned (ID
/// documents, participant phone or e-mail, gateway payloads) cannot reach the app even if a body carried it.
abstract final class OperatorBookingsJson {
  static OperatorBookingsPage page(Object? json) {
    final source = _map(json);
    return OperatorBookingsPage(
      page: _int(source['pageNumber'], min: 1),
      pageSize: _int(source['pageSize'], min: 1),
      totalCount: _int(source['totalCount'], min: 0),
      totalPages: _int(source['totalPages'], min: 0),
      summary: _summary(source['summary']),
      items: _list(source['items']).map(_listItem).toList(growable: false),
    );
  }

  static OperatorBookingDetail detail(Object? json) {
    final source = _map(json);
    final blocked = source['cancelBlockedReason'];
    return OperatorBookingDetail(
      bookingId: _id(source['bookingId']),
      bookingCode: _text(source['bookingCode']),
      status: _enum(source['status'], OperatorBookingStatus.values),
      paymentStatus: _enum(
        source['paymentStatus'],
        OperatorPaymentStatus.values,
      ),
      bookedAtUtc: _instant(source['bookedAtUtc']),
      cancelledAtUtc: _optionalInstant(source['cancelledAtUtc']),
      cancelReason: _optionalText(source['cancelReason']),
      tour: _tour(source['tour']),
      schedule: _schedule(source['schedule'], withMeetingPoint: true),
      booker: _booker(source['booker'], withPhone: true),
      quantity: _int(source['quantity'], min: 1),
      participants: _list(
        source['participants'],
      ).map(_participant).toList(growable: false),
      ticket: source['ticket'] == null ? null : _ticket(source['ticket']),
      checkInStatus: _enum(
        source['checkInStatus'],
        OperatorCheckInStatus.values,
      ),
      checkedInAtUtc: _optionalInstant(source['checkedInAtUtc']),
      payment: source['payment'] == null ? null : _payment(source['payment']),
      paidAmount: _money(source['paidAmount']),
      subtotalAmount: _money(source['subtotalAmount']),
      discountAmount: _money(source['discountAmount']),
      totalAmount: _money(source['totalAmount']),
      coupon: source['coupon'] == null ? null : _coupon(source['coupon']),
      canCancel: _bool(source['canCancel']),
      cancelBlockedReason: blocked == null
          ? null
          : _enum(blocked, OperatorCancelBlockedReason.values),
    );
  }

  /// The owned-tour list used by the tour filter (`GET /api/v1/operator/revenue/tours`, a plain array of
  /// `{ id, code, title, isActive }`). Only the id and the title are kept.
  static List<OperatorBookingTourOption> tourOptions(Object? json) {
    return _list(json)
        .map((entry) {
          final source = _map(entry);
          return OperatorBookingTourOption(
            id: '${_int(source['id'], min: 1)}',
            title: _text(source['title']),
          );
        })
        .toList(growable: false);
  }

  static OperatorBookingListItem _listItem(Object? value) {
    final source = _map(value);
    return OperatorBookingListItem(
      bookingId: _id(source['bookingId']),
      bookingCode: _text(source['bookingCode']),
      tour: _tour(source['tour']),
      schedule: _schedule(source['schedule'], withMeetingPoint: false),
      booker: _booker(source['booker'], withPhone: false),
      quantity: _int(source['quantity'], min: 1),
      totalAmount: _money(source['totalAmount']),
      discountAmount: _money(source['discountAmount']),
      status: _enum(source['status'], OperatorBookingStatus.values),
      paymentStatus: _enum(
        source['paymentStatus'],
        OperatorPaymentStatus.values,
      ),
      checkInStatus: _enum(
        source['checkInStatus'],
        OperatorCheckInStatus.values,
      ),
      checkedInAtUtc: _optionalInstant(source['checkedInAtUtc']),
      bookedAtUtc: _instant(source['bookedAtUtc']),
    );
  }

  static OperatorBookingsSummary _summary(Object? value) {
    final source = _map(value);
    return OperatorBookingsSummary(
      totalBookings: _int(source['totalBookings'], min: 0),
      totalParticipants: _int(source['totalParticipants'], min: 0),
      totalConfirmedAmount: _money(source['totalConfirmedAmount']),
    );
  }

  static OperatorBookingTour _tour(Object? value) {
    final source = _map(value);
    return OperatorBookingTour(
      tourId: _id(source['tourId']),
      title: _text(source['title']),
    );
  }

  static OperatorBookingSchedule _schedule(
    Object? value, {
    required bool withMeetingPoint,
  }) {
    final source = _map(value);
    return OperatorBookingSchedule(
      scheduleId: _id(source['scheduleId']),
      startAtUtc: _instant(source['startAtUtc']),
      endAtUtc: _instant(source['endAtUtc']),
      meetingPoint: withMeetingPoint
          ? _optionalText(source['meetingPoint'])
          : null,
    );
  }

  static OperatorBookingBooker _booker(
    Object? value, {
    required bool withPhone,
  }) {
    final source = _map(value);
    return OperatorBookingBooker(
      userId: _id(source['userId']),
      fullName: _text(source['fullName']),
      email: _optionalText(source['email']),
      phoneNumber: withPhone ? _optionalText(source['phoneNumber']) : null,
    );
  }

  static OperatorBookingParticipant _participant(Object? value) {
    final source = _map(value);
    return OperatorBookingParticipant(
      fullName: _text(source['fullName']),
      type: _enum(source['participantType'], OperatorParticipantType.values),
    );
  }

  static OperatorBookingTicket _ticket(Object? value) {
    final source = _map(value);
    return OperatorBookingTicket(
      ticketCode: _text(source['ticketCode']),
      status: _enum(source['status'], OperatorTicketStatus.values),
      issuedAtUtc: _instant(source['issuedAtUtc']),
      expiresAtUtc: _optionalInstant(source['expiresAtUtc']),
    );
  }

  static OperatorBookingPayment _payment(Object? value) {
    final source = _map(value);
    return OperatorBookingPayment(
      gateway: _enum(source['gateway'], OperatorPaymentGateway.values),
      gatewayTransactionRef: _optionalText(source['gatewayTransactionRef']),
      status: _enum(source['status'], OperatorPaymentTransactionStatus.values),
      amount: _money(source['amount']),
      succeededAtUtc: _optionalInstant(source['succeededAtUtc']),
    );
  }

  static OperatorBookingCoupon _coupon(Object? value) {
    final source = _map(value);
    return OperatorBookingCoupon(
      code: _text(source['code']),
      name: _text(source['name']),
      discountAmount: _money(source['discountAmount']),
    );
  }

  static Never _fail() => throw const FormatException(
    'The operator bookings body breaks the contract.',
  );

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : _fail();

  static List<Object?> _list(Object? value) =>
      value is List<Object?> ? value : _fail();

  static String _text(Object? value) =>
      value is String && value.isNotEmpty ? value : _fail();

  static String? _optionalText(Object? value) =>
      value == null ? null : (value is String ? value : _fail());

  static bool _bool(Object? value) => value is bool ? value : _fail();

  /// A whole number at or above [min]; a fractional value is rejected, not rounded.
  static int _int(Object? value, {required int min}) {
    if (value is! int || value < min) _fail();
    return value;
  }

  /// Ids are JSON strings holding a positive integer.
  static String _id(Object? value) {
    if (value is! String || !RegExp(r'^\d+$').hasMatch(value)) _fail();
    return value;
  }

  /// VND as the backend sends it (a decimal such as `2400000.00`); never negative or non-finite.
  static double _money(Object? value) {
    if (value is! num || value < 0 || !value.isFinite) _fail();
    return value.toDouble();
  }

  static T _enum<T extends WireValue>(Object? value, List<T> values) {
    if (value is! String) _fail();
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return _fail();
  }

  /// An ISO-8601 instant with a time part, returned in UTC.
  static DateTime _instant(Object? value) {
    final text = _text(value);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(text)) _fail();
    final parsed = DateTime.tryParse(text);
    return parsed == null ? _fail() : parsed.toUtc();
  }

  static DateTime? _optionalInstant(Object? value) =>
      value == null ? null : _instant(value);
}
