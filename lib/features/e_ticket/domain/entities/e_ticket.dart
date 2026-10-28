import 'package:equatable/equatable.dart';

/// UC-29 ticket status as shown to the Traveler (derived by the Backend).
enum ETicketStatus {
  notYetActive,
  valid,
  used,
  cancelled,
  expired;

  /// The QR is returned, and can be refreshed, only before and during the departure date.
  bool get showsQr => this == notYetActive || this == valid;
}

final class ETicketQr extends Equatable {
  const ETicketQr({required this.content, required this.issuedAtUtc});

  /// Opaque `TM1.{token}.{signature}` issued by the server; rendered as received, never built here.
  final String content;
  final DateTime issuedAtUtc;

  @override
  List<Object?> get props => [content, issuedAtUtc];
}

/// The UC-29 e-ticket of one booking (`Capstone_BE/docs/UC-29-api-contract.md`).
final class ETicket extends Equatable {
  const ETicket({
    required this.ticketId,
    required this.ticketCode,
    required this.bookingId,
    required this.bookingCode,
    required this.status,
    required this.tourId,
    required this.tourTitle,
    required this.operatorName,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.meetingPoint,
    required this.participantCount,
    required this.adults,
    required this.children,
    required this.infants,
    required this.departureDate,
    required this.validFromUtc,
    required this.validUntilUtc,
    required this.checkedInAtUtc,
    required this.qr,
  });

  final int ticketId;
  final String ticketCode;
  final int bookingId;
  final String bookingCode;
  final ETicketStatus status;
  final int tourId;
  final String tourTitle;
  final String operatorName;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String? meetingPoint;
  final int participantCount;
  final int adults;
  final int children;
  final int infants;

  /// The departure date in Asia/Ho_Chi_Minh, as a date at UTC midnight.
  final DateTime departureDate;
  final DateTime validFromUtc;
  final DateTime validUntilUtc;
  final DateTime? checkedInAtUtc;

  /// Present only for [ETicketStatus.notYetActive] and [ETicketStatus.valid].
  final ETicketQr? qr;

  @override
  List<Object?> get props => [
    ticketId,
    ticketCode,
    bookingId,
    bookingCode,
    status,
    tourId,
    tourTitle,
    operatorName,
    startAtUtc,
    endAtUtc,
    meetingPoint,
    participantCount,
    adults,
    children,
    infants,
    departureDate,
    validFromUtc,
    validUntilUtc,
    checkedInAtUtc,
    qr,
  ];
}
