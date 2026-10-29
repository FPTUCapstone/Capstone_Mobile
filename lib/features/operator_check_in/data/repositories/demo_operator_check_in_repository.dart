import 'package:trip_mate_mobile/features/operator_check_in/data/datasources/demo_operator_check_in_data.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/repositories/operator_check_in_repository.dart';

final class DemoOperatorCheckInRepository implements OperatorCheckInRepository {
  const DemoOperatorCheckInRepository();

  @override
  Future<List<OperatorDepartureSummary>> getTodayDepartures({DateTime? targetDate}) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return DemoOperatorCheckInData.sampleDepartures;
  }

  @override
  Future<DepartureProgress> getDepartureProgress(int scheduleId) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return DemoOperatorCheckInData.sampleDeparture;
  }

  @override
  Future<CheckInResult> scanCheckIn({
    required int scheduleId,
    String? qrContent,
    String? bookingCode,
    double? latitude,
    double? longitude,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final combined = '${qrContent ?? ''} ${bookingCode ?? ''}'.toLowerCase();

    if (combined.contains('already-used') || combined.contains('used')) {
      throw CheckInFailure(
        kind: CheckInFailureKind.alreadyUsed,
        message: 'This ticket was already checked in.',
        checkedInAt: DateTime.now().toUtc().subtract(const Duration(minutes: 15)),
        ticketCode: 'TK-0000000001',
        bookingCode: 'BK-20261030-001',
        passengerName: 'Nguyen Minh Phuc',
      );
    }

    if (combined.contains('wrong-schedule') || combined.contains('wrong-sched')) {
      throw const CheckInFailure(
        kind: CheckInFailureKind.wrongSchedule,
        message: 'Ticket belongs to a different departure.',
      );
    }

    if (combined.contains('invalid')) {
      throw const CheckInFailure(
        kind: CheckInFailureKind.invalidQr,
        message: 'Invalid or unverified QR code.',
      );
    }

    final code = bookingCode ?? 'TK-0000000101';
    final progress = DemoOperatorCheckInData.sampleDeparture;
    final updated = DepartureProgress(
      scheduleId: progress.scheduleId,
      tourTitle: progress.tourTitle,
      startAtUtc: progress.startAtUtc,
      endAtUtc: progress.endAtUtc,
      meetingPoint: progress.meetingPoint,
      checkedInParticipants: progress.checkedInParticipants + 1,
      totalEligibleParticipants: progress.totalEligibleParticipants,
      waitingParticipants: progress.waitingParticipants - 1,
    );

    return CheckInResult(
      ticketCode: code,
      bookingCode: bookingCode ?? 'BK-20261030-008',
      passengerName: 'Nguyen Minh Phuc',
      participantCount: 2,
      checkedInAtUtc: DateTime.now().toUtc(),
      departure: updated,
    );
  }
}
