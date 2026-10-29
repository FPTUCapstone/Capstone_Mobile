import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_check_in/data/models/operator_check_in_json.dart';
import 'package:trip_mate_mobile/features/operator_check_in/data/repositories/demo_operator_check_in_repository.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';

void main() {
  group('OperatorCheckInJson Parser', () {
    test('parses departure summary list correctly', () {
      final json = [
        {
          'scheduleId': 101,
          'tourId': 1,
          'tourTitle': 'Hanoi Old Quarter & Street Food Walking Tour',
          'startAtUtc': '2026-10-30T08:00:00Z',
          'endAtUtc': '2026-10-30T17:00:00Z',
          'meetingPoint': 'Hanoi Opera House, 1 Trang Tien, Hoan Kiem, Hanoi',
          'status': 'Open',
          'checkedInParticipants': 18,
          'totalEligibleParticipants': 31,
          'waitingParticipants': 13,
        }
      ];

      final list = OperatorCheckInJson.departureSummaryList(json);
      expect(list.length, 1);
      final item = list.first;
      expect(item.scheduleId, 101);
      expect(item.tourId, 1);
      expect(item.tourTitle, 'Hanoi Old Quarter & Street Food Walking Tour');
      expect(item.checkedInParticipants, 18);
      expect(item.totalEligibleParticipants, 31);
      expect(item.waitingParticipants, 13);
      expect(item.isFullyCheckedIn, isFalse);
    });

    test('parses departure progress correctly', () {
      final json = {
        'scheduleId': 101,
        'tourTitle': 'Hanoi Old Quarter & Street Food Walking Tour',
        'startAtUtc': '2026-10-30T08:00:00Z',
        'endAtUtc': '2026-10-30T17:00:00Z',
        'meetingPoint': 'Hanoi Opera House',
        'checkedInParticipants': 31,
        'totalEligibleParticipants': 31,
        'waitingParticipants': 0,
      };

      final progress = OperatorCheckInJson.departureProgress(json);
      expect(progress.scheduleId, 101);
      expect(progress.checkedInParticipants, 31);
      expect(progress.totalEligibleParticipants, 31);
      expect(progress.waitingParticipants, 0);
      expect(progress.isFullyCheckedIn, isTrue);
    });

    test('parses check-in result correctly', () {
      final json = {
        'ticketCode': 'TK-20261030-0012',
        'bookingCode': 'BK-20261030-0042',
        'passengerName': 'Le Thi Thu Ha',
        'participantCount': 2,
        'checkedInAtUtc': '2026-10-30T08:24:00Z',
        'departure': {
          'scheduleId': 101,
          'tourTitle': 'Hanoi Old Quarter Tour',
          'startAtUtc': '2026-10-30T08:00:00Z',
          'endAtUtc': '2026-10-30T17:00:00Z',
          'meetingPoint': 'Opera House',
          'checkedInParticipants': 19,
          'totalEligibleParticipants': 31,
          'waitingParticipants': 12,
        },
      };

      final result = OperatorCheckInJson.checkInResult(json);
      expect(result.ticketCode, 'TK-20261030-0012');
      expect(result.bookingCode, 'BK-20261030-0042');
      expect(result.passengerName, 'Le Thi Thu Ha');
      expect(result.participantCount, 2);
      expect(result.departure.checkedInParticipants, 19);
    });
  });

  group('DemoOperatorCheckInRepository', () {
    const repo = DemoOperatorCheckInRepository();

    test('getTodayDepartures returns predefined demo departures', () async {
      final departures = await repo.getTodayDepartures();
      expect(departures, isNotEmpty);
      expect(departures.first.scheduleId, 101);
    });

    test('getDepartureProgress returns departure progress', () async {
      final progress = await repo.getDepartureProgress(101);
      expect(progress.scheduleId, 101);
      expect(progress.totalEligibleParticipants, greaterThan(0));
    });

    test('scanCheckIn returns success for valid code', () async {
      final result = await repo.scanCheckIn(
        scheduleId: 101,
        bookingCode: 'BK-20261030-0042',
      );

      expect(result.bookingCode, 'BK-20261030-0042');
      expect(result.participantCount, greaterThan(0));
    });

    test('scanCheckIn throws alreadyUsed for already used code', () async {
      expect(
        () => repo.scanCheckIn(
          scheduleId: 101,
          bookingCode: 'USED-001',
        ),
        throwsA(
          isA<CheckInFailure>().having(
            (f) => f.kind,
            'kind',
            CheckInFailureKind.alreadyUsed,
          ),
        ),
      );
    });

    test('scanCheckIn throws wrongSchedule for wrong schedule code', () async {
      expect(
        () => repo.scanCheckIn(
          scheduleId: 101,
          bookingCode: 'WRONG-SCHED',
        ),
        throwsA(
          isA<CheckInFailure>().having(
            (f) => f.kind,
            'kind',
            CheckInFailureKind.wrongSchedule,
          ),
        ),
      );
    });
  });
}
