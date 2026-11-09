import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/emergency_tour/domain/entities/emergency_action.dart';

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

  bool get isStopped => action == EmergencyAction.emergencyStop;
  bool get isAcknowledged => acknowledgedAtUtc != null;

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
  ];
}
