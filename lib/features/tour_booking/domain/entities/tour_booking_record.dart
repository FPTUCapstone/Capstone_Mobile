import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/booking_contact_info.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/booking_participant.dart';

/// Canonical booking lifecycle status across UC-27, UC-28, and UC-29.
enum BookingLifecycleStatus { pendingPayment, confirmed, cancelled, expired }

/// Supported electronic payment gateway methods in UC-28 (Screen #67).
/// Strictly limited to VNPay and PayOS per canonical specification.
enum PaymentGatewayMethod { vnpay, payos }

/// Server-driven payment verification status (BR-71, BR-73, PC-06).
enum PaymentVerificationStatus {
  notStarted,
  redirectingToGateway,
  pendingVerification,
  verifiedSuccess,
  failedOrCancelled,
  timeout,
  reconciliationRequired,
}

/// Canonical QR E-ticket lifecycle status for UC-29 (Screen #69).
enum TicketLifecycleStatus { valid, notYetActive, used, cancelled, expired }

/// Represents a Payment Transaction record created when initiating electronic payment (BR-71).
final class PaymentTransactionRecord extends Equatable {
  const PaymentTransactionRecord({
    required this.transactionId,
    required this.bookingId,
    required this.method,
    required this.amountVnd,
    this.currency = 'VND',
    required this.status,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.gatewayReference,
  });

  final String transactionId;
  final String bookingId;
  final PaymentGatewayMethod method;
  final int amountVnd;
  final String currency;
  final PaymentVerificationStatus status;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final String? gatewayReference;

  PaymentTransactionRecord copyWith({
    PaymentGatewayMethod? method,
    PaymentVerificationStatus? status,
    DateTime? updatedAtUtc,
    String? gatewayReference,
  }) {
    return PaymentTransactionRecord(
      transactionId: transactionId,
      bookingId: bookingId,
      method: method ?? this.method,
      amountVnd: amountVnd,
      currency: currency,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      gatewayReference: gatewayReference ?? this.gatewayReference,
    );
  }

  @override
  List<Object?> get props => [
    transactionId,
    bookingId,
    method,
    amountVnd,
    currency,
    status,
    createdAtUtc,
    updatedAtUtc,
    gatewayReference,
  ];
}

/// Represents an issued QR E-ticket record for a Confirmed booking (BR-80, BR-82, BR-86).
final class QrEticketRecord extends Equatable {
  const QrEticketRecord({
    required this.ticketId,
    required this.bookingId,
    required this.opaqueQrPayload,
    required this.ticketStatus,
    required this.issuedAtUtc,
    required this.lastRefreshedAtUtc,
    required this.refreshVersion,
    required this.validityWindowNote,
  });

  final String ticketId;
  final String bookingId;

  /// Opaque deterministic Demo QR payload or server-signed token.
  /// Never forged in production mode.
  final String opaqueQrPayload;
  final TicketLifecycleStatus ticketStatus;
  final DateTime issuedAtUtc;
  final DateTime lastRefreshedAtUtc;
  final int refreshVersion;
  final String validityWindowNote;

  QrEticketRecord copyWith({
    String? opaqueQrPayload,
    TicketLifecycleStatus? ticketStatus,
    DateTime? lastRefreshedAtUtc,
    int? refreshVersion,
    String? validityWindowNote,
  }) {
    return QrEticketRecord(
      ticketId: ticketId,
      bookingId: bookingId,
      opaqueQrPayload: opaqueQrPayload ?? this.opaqueQrPayload,
      ticketStatus: ticketStatus ?? this.ticketStatus,
      issuedAtUtc: issuedAtUtc,
      lastRefreshedAtUtc: lastRefreshedAtUtc ?? this.lastRefreshedAtUtc,
      refreshVersion: refreshVersion ?? this.refreshVersion,
      validityWindowNote: validityWindowNote ?? this.validityWindowNote,
    );
  }

  @override
  List<Object?> get props => [
    ticketId,
    bookingId,
    opaqueQrPayload,
    ticketStatus,
    issuedAtUtc,
    lastRefreshedAtUtc,
    refreshVersion,
    validityWindowNote,
  ];
}

/// Represents a Tour Booking across UC-27, UC-28, and UC-29.
final class TourBookingRecord extends Equatable {
  const TourBookingRecord({
    required this.bookingId,
    required this.ownerTravelerId,
    required this.tourId,
    required this.tourTitle,
    required this.operatorName,
    required this.scheduleId,
    required this.departureAtUtc,
    required this.returnAtUtc,
    required this.durationDays,
    required this.meetingPoint,
    required this.participantCount,
    required this.participants,
    required this.contactInfo,
    required this.unitPrice,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    this.currency = 'VND',
    this.appliedVoucherCode,
    required this.status,
    required this.createdAtUtc,
    required this.paymentExpiresAtUtc,
    this.latestTransaction,
    this.eticket,
  });

  final String bookingId;
  final String ownerTravelerId;
  final String tourId;
  final String tourTitle;
  final String operatorName;
  final String scheduleId;
  final DateTime departureAtUtc;
  final DateTime returnAtUtc;
  final int durationDays;
  final String meetingPoint;
  final int participantCount;
  final List<BookingParticipant> participants;
  final BookingContactInfo contactInfo;
  final int unitPrice;
  final int subtotal;
  final int discountAmount;
  final int totalAmount;
  final String currency;
  final String? appliedVoucherCode;
  final BookingLifecycleStatus status;
  final DateTime createdAtUtc;
  final DateTime paymentExpiresAtUtc;
  final PaymentTransactionRecord? latestTransaction;
  final QrEticketRecord? eticket;

  TourBookingRecord copyWith({
    String? ownerTravelerId,
    BookingLifecycleStatus? status,
    DateTime? paymentExpiresAtUtc,
    PaymentTransactionRecord? latestTransaction,
    QrEticketRecord? eticket,
    bool clearEticket = false,
  }) {
    return TourBookingRecord(
      bookingId: bookingId,
      ownerTravelerId: ownerTravelerId ?? this.ownerTravelerId,
      tourId: tourId,
      tourTitle: tourTitle,
      operatorName: operatorName,
      scheduleId: scheduleId,
      departureAtUtc: departureAtUtc,
      returnAtUtc: returnAtUtc,
      durationDays: durationDays,
      meetingPoint: meetingPoint,
      participantCount: participantCount,
      participants: participants,
      contactInfo: contactInfo,
      unitPrice: unitPrice,
      subtotal: subtotal,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
      currency: currency,
      appliedVoucherCode: appliedVoucherCode,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
      paymentExpiresAtUtc: paymentExpiresAtUtc ?? this.paymentExpiresAtUtc,
      latestTransaction: latestTransaction ?? this.latestTransaction,
      eticket: clearEticket ? null : (eticket ?? this.eticket),
    );
  }

  @override
  List<Object?> get props => [
    bookingId,
    ownerTravelerId,
    tourId,
    tourTitle,
    operatorName,
    scheduleId,
    departureAtUtc,
    returnAtUtc,
    durationDays,
    meetingPoint,
    participantCount,
    participants,
    contactInfo,
    unitPrice,
    subtotal,
    discountAmount,
    totalAmount,
    currency,
    appliedVoucherCode,
    status,
    createdAtUtc,
    paymentExpiresAtUtc,
    latestTransaction,
    eticket,
  ];
}
