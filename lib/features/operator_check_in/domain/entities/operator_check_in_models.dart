import 'package:equatable/equatable.dart';

class DepartureProgress extends Equatable {
  const DepartureProgress({
    required this.scheduleId,
    required this.tourTitle,
    required this.startAtUtc,
    required this.endAtUtc,
    this.meetingPoint,
    required this.checkedInParticipants,
    required this.totalEligibleParticipants,
    required this.waitingParticipants,
  });

  final int scheduleId;
  final String tourTitle;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String? meetingPoint;
  final int checkedInParticipants;
  final int totalEligibleParticipants;
  final int waitingParticipants;

  double get progressRatio => totalEligibleParticipants <= 0
      ? 0.0
      : (checkedInParticipants / totalEligibleParticipants).clamp(0.0, 1.0);

  int get progressPercent => (progressRatio * 100).round();

  bool get isFullyCheckedIn =>
      totalEligibleParticipants > 0 &&
      checkedInParticipants >= totalEligibleParticipants;

  @override
  List<Object?> get props => [
    scheduleId,
    tourTitle,
    startAtUtc,
    endAtUtc,
    meetingPoint,
    checkedInParticipants,
    totalEligibleParticipants,
    waitingParticipants,
  ];
}

class OperatorDepartureSummary extends Equatable {
  const OperatorDepartureSummary({
    required this.scheduleId,
    required this.tourId,
    required this.tourTitle,
    required this.startAtUtc,
    required this.endAtUtc,
    this.meetingPoint,
    required this.status,
    required this.checkedInParticipants,
    required this.totalEligibleParticipants,
    required this.waitingParticipants,
  });

  final int scheduleId;
  final int tourId;
  final String tourTitle;
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String? meetingPoint;
  final String status;
  final int checkedInParticipants;
  final int totalEligibleParticipants;
  final int waitingParticipants;

  double get progressRatio => totalEligibleParticipants <= 0
      ? 0.0
      : (checkedInParticipants / totalEligibleParticipants).clamp(0.0, 1.0);

  int get progressPercent => (progressRatio * 100).round();

  bool get isFullyCheckedIn =>
      totalEligibleParticipants > 0 &&
      checkedInParticipants >= totalEligibleParticipants;

  @override
  List<Object?> get props => [
    scheduleId,
    tourId,
    tourTitle,
    startAtUtc,
    endAtUtc,
    meetingPoint,
    status,
    checkedInParticipants,
    totalEligibleParticipants,
    waitingParticipants,
  ];
}

class CheckInResult extends Equatable {
  const CheckInResult({
    required this.ticketCode,
    required this.bookingCode,
    required this.passengerName,
    required this.participantCount,
    required this.checkedInAtUtc,
    required this.departure,
  });

  final String ticketCode;
  final String bookingCode;
  final String passengerName;
  final int participantCount;
  final DateTime checkedInAtUtc;
  final DepartureProgress departure;

  @override
  List<Object?> get props => [
    ticketCode,
    bookingCode,
    passengerName,
    participantCount,
    checkedInAtUtc,
    departure,
  ];
}

enum CheckInScanStatus { valid, alreadyUsed, rejected }

class CheckInScanItem extends Equatable {
  const CheckInScanItem({
    required this.code,
    required this.passengerName,
    required this.participantCount,
    required this.timestamp,
    required this.status,
    this.reason,
  });

  final String code;
  final String passengerName;
  final int participantCount;
  final DateTime timestamp;
  final CheckInScanStatus status;
  final String? reason;

  @override
  List<Object?> get props => [
    code,
    passengerName,
    participantCount,
    timestamp,
    status,
    reason,
  ];
}

enum CheckInFailureKind {
  unauthorized,
  forbidden,
  scheduleNotFound,
  scheduleForbidden,
  departureNotToday,
  invalidQr,
  ticketNotFound,
  wrongSchedule,
  bookingCancelled,
  bookingNotConfirmed,
  alreadyUsed,
  ticketInvalid,
  invalidInput,
  network,
  cameraPermissionDenied,
  system,
}

class CheckInFailure extends Equatable {
  const CheckInFailure({
    required this.kind,
    this.message,
    this.checkedInAt,
    this.ticketCode,
    this.bookingCode,
    this.passengerName,
  });

  final CheckInFailureKind kind;
  final String? message;
  final DateTime? checkedInAt;
  final String? ticketCode;
  final String? bookingCode;
  final String? passengerName;

  @override
  List<Object?> get props => [
    kind,
    message,
    checkedInAt,
    ticketCode,
    bookingCode,
    passengerName,
  ];
}
