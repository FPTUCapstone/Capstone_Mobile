import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';

/// How the payment of a booking affected by a UC-70 decision is refunded.
/// [unknown] covers an older Backend that does not send the value, and any
/// future value, so the page falls back to a neutral line.
enum RefundHandling {
  /// A 100% refund request was created for this booking.
  refundSubmitted,

  /// The booking was paid; TripMate reviews the refund case by case.
  underReview,

  /// Nothing was paid, so there is nothing to refund.
  notApplicable,
  unknown;

  static RefundHandling fromWire(Object? value) => switch (value) {
    'RefundSubmitted' => refundSubmitted,
    'UnderReview' => underReview,
    'NotApplicable' => notApplicable,
    _ => unknown,
  };
}

/// Discovery data for one affected booking; the detail stays behind the status
/// endpoint. Exists only when the Backend reports a real emergency operation.
final class TravelerEmergencyNotice extends Equatable {
  const TravelerEmergencyNotice({
    required this.bookingId,
    required this.scheduleId,
    required this.action,
    required this.committedAtUtc,
    this.acknowledgedAtUtc,
  });

  final int bookingId;
  final int scheduleId;
  final EmergencyAction action;
  final DateTime committedAtUtc;
  final DateTime? acknowledgedAtUtc;

  bool get requiresAcknowledgement => acknowledgedAtUtc == null;

  @override
  List<Object?> get props => [
    bookingId,
    scheduleId,
    action,
    committedAtUtc,
    acknowledgedAtUtc,
  ];
}

/// The committed UC-70 decision visible to the owner of the affected booking.
final class TravelerEmergencyStatus extends Equatable {
  const TravelerEmergencyStatus({
    required this.bookingId,
    required this.tourScheduleId,
    required this.bookingStatus,
    required this.scheduleStatus,
    required this.totalTicketCount,
    required this.cancelledTicketCount,
    required this.usedTicketCount,
    required this.action,
    required this.reasonCategory,
    required this.reasonDetails,
    required this.committedAtUtc,
    this.immediateInstructions,
    this.emergencyContact,
    this.acknowledgedAtUtc,
    this.refundHandling = RefundHandling.unknown,
    this.tourId,
  });

  static final _phone = RegExp(r'\+?\d[\d\s().-]{6,}\d');

  final int bookingId;
  final int tourScheduleId;
  final String bookingStatus;
  final String scheduleStatus;
  final int totalTicketCount;
  final int cancelledTicketCount;
  final int usedTicketCount;
  final EmergencyAction action;
  final String reasonCategory;
  final String reasonDetails;
  final DateTime committedAtUtc;
  final String? immediateInstructions;
  final String? emergencyContact;

  /// Receipt only: it does not mean the Traveler is safe.
  final DateTime? acknowledgedAtUtc;

  final RefundHandling refundHandling;

  /// The tour of the cancelled departure; absent on an older Backend.
  final int? tourId;

  bool get isStopped => action == EmergencyAction.emergencyStop;
  bool get isAcknowledged => acknowledgedAtUtc != null;

  bool get hasRefundRequest => refundHandling == RefundHandling.refundSubmitted;

  /// The tour to book again: only a departure cancelled before it started,
  /// and only when the Backend names its tour.
  int? get rebookableTourId =>
      action == EmergencyAction.cancelBeforeDeparture ? tourId : null;

  /// The first phone number in the free-text contact, ready for a `tel:` link.
  String? get dialableContact {
    final match = _phone.firstMatch(emergencyContact ?? '');
    return match?.group(0)?.replaceAll(RegExp(r'[\s().-]'), '');
  }

  TravelerEmergencyStatus acknowledged(DateTime at) => TravelerEmergencyStatus(
    bookingId: bookingId,
    tourScheduleId: tourScheduleId,
    bookingStatus: bookingStatus,
    scheduleStatus: scheduleStatus,
    totalTicketCount: totalTicketCount,
    cancelledTicketCount: cancelledTicketCount,
    usedTicketCount: usedTicketCount,
    action: action,
    reasonCategory: reasonCategory,
    reasonDetails: reasonDetails,
    committedAtUtc: committedAtUtc,
    immediateInstructions: immediateInstructions,
    emergencyContact: emergencyContact,
    acknowledgedAtUtc: at,
    refundHandling: refundHandling,
    tourId: tourId,
  );

  @override
  List<Object?> get props => [
    bookingId,
    tourScheduleId,
    bookingStatus,
    scheduleStatus,
    totalTicketCount,
    cancelledTicketCount,
    usedTicketCount,
    action,
    reasonCategory,
    reasonDetails,
    committedAtUtc,
    immediateInstructions,
    emergencyContact,
    acknowledgedAtUtc,
    refundHandling,
    tourId,
  ];
}
