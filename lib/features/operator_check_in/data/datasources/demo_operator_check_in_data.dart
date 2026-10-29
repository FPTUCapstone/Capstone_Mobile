import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';

abstract final class DemoOperatorCheckInData {
  static final sampleDeparture = DepartureProgress(
    scheduleId: 101,
    tourTitle: 'Ba Na Hills Full-Day Tour',
    startAtUtc: DateTime.now().toUtc(),
    endAtUtc: DateTime.now().toUtc().add(const Duration(hours: 8)),
    meetingPoint: 'Muong Thanh Grand Da Nang lobby',
    checkedInParticipants: 18,
    totalEligibleParticipants: 31,
    waitingParticipants: 13,
  );

  static final sampleDepartures = <OperatorDepartureSummary>[
    OperatorDepartureSummary(
      scheduleId: 101,
      tourId: 45,
      tourTitle: 'Ba Na Hills Full-Day Tour',
      startAtUtc: DateTime.now().toUtc(),
      endAtUtc: DateTime.now().toUtc().add(const Duration(hours: 8)),
      meetingPoint: 'Muong Thanh Grand Da Nang lobby',
      status: 'Boarding',
      checkedInParticipants: 18,
      totalEligibleParticipants: 31,
      waitingParticipants: 13,
    ),
    OperatorDepartureSummary(
      scheduleId: 102,
      tourId: 46,
      tourTitle: 'Hoi An Lantern & Ancient Town Evening',
      startAtUtc: DateTime.now().toUtc().add(const Duration(hours: 4)),
      endAtUtc: DateTime.now().toUtc().add(const Duration(hours: 9)),
      meetingPoint: 'Champa Museum bus station',
      status: 'Scheduled',
      checkedInParticipants: 0,
      totalEligibleParticipants: 24,
      waitingParticipants: 24,
    ),
  ];
}
