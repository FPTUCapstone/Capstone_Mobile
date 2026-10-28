import 'package:equatable/equatable.dart';

/// An enum whose value is a fixed backend string.
abstract interface class WireValue {
  String get wire;
}

/// Backend `BookingStatus`.
enum OperatorBookingStatus implements WireValue {
  pendingPayment('PendingPayment'),
  confirmed('Confirmed'),
  cancelled('Cancelled'),
  completed('Completed'),
  expired('Expired');

  const OperatorBookingStatus(this.wire);

  /// The value used on the wire and in the `status` query parameter.
  @override
  final String wire;
}

/// Backend `PaymentStatus`.
enum OperatorPaymentStatus implements WireValue {
  unpaid('Unpaid'),
  paid('Paid'),
  refunded('Refunded'),
  partiallyRefunded('PartiallyRefunded');

  const OperatorPaymentStatus(this.wire);

  @override
  final String wire;
}

/// Derived by the backend from the booking's tickets; UC-43 records the check-in.
enum OperatorCheckInStatus implements WireValue {
  notCheckedIn('NotCheckedIn'),
  checkedIn('CheckedIn');

  const OperatorCheckInStatus(this.wire);

  @override
  final String wire;
}

/// Backend `ParticipantType`.
enum OperatorParticipantType implements WireValue {
  adult('Adult'),
  child('Child'),
  infant('Infant');

  const OperatorParticipantType(this.wire);

  @override
  final String wire;
}

/// Backend `PaymentGateway`.
enum OperatorPaymentGateway implements WireValue {
  mock('Mock'),
  payOs('PayOS'),
  vnPay('VNPAY'),
  moMo('MoMo'),
  stripe('Stripe');

  const OperatorPaymentGateway(this.wire);

  @override
  final String wire;
}

/// Backend `TicketStatus`.
enum OperatorTicketStatus implements WireValue {
  valid('Valid'),
  used('Used'),
  cancelled('Cancelled'),
  expired('Expired');

  const OperatorTicketStatus(this.wire);

  @override
  final String wire;
}

/// Backend `PaymentTransactionStatus`.
enum OperatorPaymentTransactionStatus implements WireValue {
  pending('Pending'),
  success('Success'),
  cancelled('Cancelled'),
  expired('Expired'),
  failed('Failed');

  const OperatorPaymentTransactionStatus(this.wire);

  @override
  final String wire;
}

/// Why the backend says the operator cannot cancel a booking (the UC-41 rule). Kept for the UC-41 task;
/// no control uses it in UC-40.
enum OperatorCancelBlockedReason implements WireValue {
  invalidStatus('InvalidStatus'),
  checkedIn('CheckedIn');

  const OperatorCancelBlockedReason(this.wire);

  @override
  final String wire;
}

final class OperatorBookingTour extends Equatable {
  const OperatorBookingTour({required this.tourId, required this.title});

  final String tourId;
  final String title;

  @override
  List<Object?> get props => [tourId, title];
}

/// [meetingPoint] is only returned by the detail endpoint.
final class OperatorBookingSchedule extends Equatable {
  const OperatorBookingSchedule({
    required this.scheduleId,
    required this.startAtUtc,
    required this.endAtUtc,
    this.meetingPoint,
  });

  final String scheduleId;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String? meetingPoint;

  @override
  List<Object?> get props => [scheduleId, startAtUtc, endAtUtc, meetingPoint];
}

/// [phoneNumber] is only returned by the detail endpoint.
final class OperatorBookingBooker extends Equatable {
  const OperatorBookingBooker({
    required this.userId,
    required this.fullName,
    this.email,
    this.phoneNumber,
  });

  final String userId;
  final String fullName;
  final String? email;
  final String? phoneNumber;

  @override
  List<Object?> get props => [userId, fullName, email, phoneNumber];
}

/// One row of the list (`GET /api/v1/operator/bookings`). Money is VND as the backend sends it (decimal).
final class OperatorBookingListItem extends Equatable {
  const OperatorBookingListItem({
    required this.bookingId,
    required this.bookingCode,
    required this.tour,
    required this.schedule,
    required this.booker,
    required this.quantity,
    required this.totalAmount,
    required this.discountAmount,
    required this.status,
    required this.paymentStatus,
    required this.checkInStatus,
    required this.bookedAtUtc,
    this.checkedInAtUtc,
  });

  final String bookingId;
  final String bookingCode;
  final OperatorBookingTour tour;
  final OperatorBookingSchedule schedule;
  final OperatorBookingBooker booker;
  final int quantity;
  final double totalAmount;
  final double discountAmount;
  final OperatorBookingStatus status;
  final OperatorPaymentStatus paymentStatus;
  final OperatorCheckInStatus checkInStatus;
  final DateTime? checkedInAtUtc;
  final DateTime bookedAtUtc;

  @override
  List<Object?> get props => [
    bookingId,
    bookingCode,
    tour,
    schedule,
    booker,
    quantity,
    totalAmount,
    discountAmount,
    status,
    paymentStatus,
    checkInStatus,
    checkedInAtUtc,
    bookedAtUtc,
  ];
}

/// The passenger manifest entry: name and type only. ID documents, phone, e-mail and nationality are never
/// returned by the backend and never modelled here.
final class OperatorBookingParticipant extends Equatable {
  const OperatorBookingParticipant({
    required this.fullName,
    required this.type,
  });

  final String fullName;
  final OperatorParticipantType type;

  @override
  List<Object?> get props => [fullName, type];
}

final class OperatorBookingTicket extends Equatable {
  const OperatorBookingTicket({
    required this.ticketCode,
    required this.status,
    required this.issuedAtUtc,
    this.expiresAtUtc,
  });

  final String ticketCode;
  final OperatorTicketStatus status;
  final DateTime issuedAtUtc;
  final DateTime? expiresAtUtc;

  @override
  List<Object?> get props => [ticketCode, status, issuedAtUtc, expiresAtUtc];
}

/// Read-only projection of the verified payment (BR-77). Gateway payloads and checkout data are never returned.
final class OperatorBookingPayment extends Equatable {
  const OperatorBookingPayment({
    required this.gateway,
    required this.status,
    required this.amount,
    this.gatewayTransactionRef,
    this.succeededAtUtc,
  });

  final OperatorPaymentGateway gateway;
  final String? gatewayTransactionRef;
  final OperatorPaymentTransactionStatus status;
  final double amount;
  final DateTime? succeededAtUtc;

  @override
  List<Object?> get props => [
    gateway,
    gatewayTransactionRef,
    status,
    amount,
    succeededAtUtc,
  ];
}

final class OperatorBookingCoupon extends Equatable {
  const OperatorBookingCoupon({
    required this.code,
    required this.name,
    required this.discountAmount,
  });

  final String code;
  final String name;
  final double discountAmount;

  @override
  List<Object?> get props => [code, name, discountAmount];
}

/// `GET /api/v1/operator/bookings/{bookingId}`.
final class OperatorBookingDetail extends Equatable {
  const OperatorBookingDetail({
    required this.bookingId,
    required this.bookingCode,
    required this.status,
    required this.paymentStatus,
    required this.bookedAtUtc,
    required this.tour,
    required this.schedule,
    required this.booker,
    required this.quantity,
    required this.participants,
    required this.checkInStatus,
    required this.paidAmount,
    required this.subtotalAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.canCancel,
    this.cancelledAtUtc,
    this.cancelReason,
    this.ticket,
    this.checkedInAtUtc,
    this.payment,
    this.coupon,
    this.cancelBlockedReason,
  });

  final String bookingId;
  final String bookingCode;
  final OperatorBookingStatus status;
  final OperatorPaymentStatus paymentStatus;
  final DateTime bookedAtUtc;
  final DateTime? cancelledAtUtc;
  final String? cancelReason;
  final OperatorBookingTour tour;
  final OperatorBookingSchedule schedule;
  final OperatorBookingBooker booker;
  final int quantity;
  final List<OperatorBookingParticipant> participants;
  final OperatorBookingTicket? ticket;
  final OperatorCheckInStatus checkInStatus;
  final DateTime? checkedInAtUtc;
  final OperatorBookingPayment? payment;
  final double paidAmount;
  final double subtotalAmount;
  final double discountAmount;
  final double totalAmount;
  final OperatorBookingCoupon? coupon;
  final bool canCancel;
  final OperatorCancelBlockedReason? cancelBlockedReason;

  @override
  List<Object?> get props => [
    bookingId,
    bookingCode,
    status,
    paymentStatus,
    bookedAtUtc,
    cancelledAtUtc,
    cancelReason,
    tour,
    schedule,
    booker,
    quantity,
    participants,
    ticket,
    checkInStatus,
    checkedInAtUtc,
    payment,
    paidAmount,
    subtotalAmount,
    discountAmount,
    totalAmount,
    coupon,
    canCancel,
    cancelBlockedReason,
  ];
}

/// Computed by the backend over the whole filtered set; never recomputed on the device. Participants and
/// amount count Confirmed + Completed bookings only.
final class OperatorBookingsSummary extends Equatable {
  const OperatorBookingsSummary({
    required this.totalBookings,
    required this.totalParticipants,
    required this.totalConfirmedAmount,
  });

  static const empty = OperatorBookingsSummary(
    totalBookings: 0,
    totalParticipants: 0,
    totalConfirmedAmount: 0,
  );

  final int totalBookings;
  final int totalParticipants;
  final double totalConfirmedAmount;

  @override
  List<Object?> get props => [
    totalBookings,
    totalParticipants,
    totalConfirmedAmount,
  ];
}

final class OperatorBookingsPage extends Equatable {
  const OperatorBookingsPage({
    required this.items,
    required this.summary,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  final List<OperatorBookingListItem> items;
  final OperatorBookingsSummary summary;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  @override
  List<Object?> get props => [
    items,
    summary,
    page,
    pageSize,
    totalCount,
    totalPages,
  ];
}

/// An owned tour offered by the tour filter.
final class OperatorBookingTourOption extends Equatable {
  const OperatorBookingTourOption({required this.id, required this.title});

  final String id;
  final String title;

  @override
  List<Object?> get props => [id, title];
}

/// What `GET /api/v1/operator/bookings` accepts. [departureFrom] and [departureTo] are calendar days (the
/// year, month and day are sent, as Vietnam days); callers normalise them, for example with
/// `TripFormatters.toCivilCalendarDay`.
final class OperatorBookingsQuery extends Equatable {
  const OperatorBookingsQuery({
    this.tourId,
    this.status,
    this.departureFrom,
    this.departureTo,
    this.keyword,
    this.page = 1,
    this.pageSize = defaultPageSize,
  });

  /// CR-01.
  static const int defaultPageSize = 20;

  /// The longest keyword the backend accepts; a longer one is rejected there.
  static const int maxKeywordLength = 200;

  final String? tourId;
  final OperatorBookingStatus? status;
  final DateTime? departureFrom;
  final DateTime? departureTo;
  final String? keyword;
  final int page;
  final int pageSize;

  @override
  List<Object?> get props => [
    tourId,
    status,
    departureFrom,
    departureTo,
    keyword,
    page,
    pageSize,
  ];
}
