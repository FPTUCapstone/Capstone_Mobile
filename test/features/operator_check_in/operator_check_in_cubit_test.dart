import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/repositories/operator_check_in_repository.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/usecases/operator_check_in_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_cubit.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_state.dart';

final class _MockCheckInRepository implements OperatorCheckInRepository {
  List<OperatorDepartureSummary> departuresToReturn = [
    OperatorDepartureSummary(
      scheduleId: 101,
      tourId: 1,
      tourTitle: 'Hanoi Heritage Tour',
      startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
      endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
      meetingPoint: 'Hanoi Opera House',
      status: 'Open',
      checkedInParticipants: 10,
      totalEligibleParticipants: 20,
      waitingParticipants: 10,
    ),
  ];

  DepartureProgress? progressToReturn;
  CheckInResult? resultToReturn;
  CheckInFailure? failureToThrow;
  Object? genericExceptionToThrow;

  int? lastProgressScheduleId;
  int? lastScanScheduleId;
  String? lastScanQrContent;
  String? lastScanBookingCode;

  @override
  Future<List<OperatorDepartureSummary>> getTodayDepartures({
    DateTime? targetDate,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    if (genericExceptionToThrow != null) throw genericExceptionToThrow!;
    return departuresToReturn;
  }

  @override
  Future<DepartureProgress> getDepartureProgress(int scheduleId) async {
    lastProgressScheduleId = scheduleId;
    if (failureToThrow != null) throw failureToThrow!;
    if (genericExceptionToThrow != null) throw genericExceptionToThrow!;
    return progressToReturn ??
        DepartureProgress(
          scheduleId: scheduleId,
          tourTitle: 'Hanoi Heritage Tour',
          startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
          endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
          meetingPoint: 'Hanoi Opera House',
          checkedInParticipants: 10,
          totalEligibleParticipants: 20,
          waitingParticipants: 10,
        );
  }

  @override
  Future<CheckInResult> scanCheckIn({
    required int scheduleId,
    String? qrContent,
    String? bookingCode,
    double? latitude,
    double? longitude,
  }) async {
    lastScanScheduleId = scheduleId;
    lastScanQrContent = qrContent;
    lastScanBookingCode = bookingCode;

    if (failureToThrow != null) throw failureToThrow!;
    if (genericExceptionToThrow != null) throw genericExceptionToThrow!;

    return resultToReturn ??
        CheckInResult(
          ticketCode: 'TK-0000000501',
          bookingCode: 'BK-20261030-001',
          passengerName: 'Nguyen Van A',
          participantCount: 2,
          checkedInAtUtc: DateTime.utc(2026, 10, 30, 8, 15),
          departure: DepartureProgress(
            scheduleId: scheduleId,
            tourTitle: 'Hanoi Heritage Tour',
            startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
            endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
            meetingPoint: 'Hanoi Opera House',
            checkedInParticipants: 12,
            totalEligibleParticipants: 20,
            waitingParticipants: 8,
          ),
        );
  }
}

void main() {
  late _MockCheckInRepository repository;
  late OperatorCheckInCubit cubit;

  setUp(() {
    repository = _MockCheckInRepository();
    cubit = OperatorCheckInCubit(
      getTodayDepartures: GetOperatorTodayDeparturesUseCase(repository),
      getDepartureProgress: GetDepartureProgressUseCase(repository),
      scanCheckIn: ScanCheckInUseCase(repository),
    );
  });

  tearDown(() => cubit.close());

  for (final kind in [
    null,
    CheckInFailureKind.alreadyUsed,
    CheckInFailureKind.ticketInvalid,
    CheckInFailureKind.network,
    CheckInFailureKind.system,
  ]) {
    test('recent history is bounded newest-first for $kind', () async {
      await cubit.loadInitial();
      final items = <CheckInScanItem>[];
      for (var index = 1; index <= 100; index++) {
        repository.failureToThrow = kind == null
            ? null
            : CheckInFailure(kind: kind, ticketCode: 'TK-$index');
        if (kind == null) {
          repository.resultToReturn = CheckInResult(
            ticketCode: 'TK-$index',
            bookingCode: 'BK-$index',
            passengerName: 'Traveler $index',
            participantCount: 2,
            checkedInAtUtc: DateTime.utc(2026, 10, 30, 8, index),
            departure: (cubit.state as OperatorCheckInLoaded).progress!,
          );
        }
        cubit.clearActiveBanner();
        await cubit.submitScan(qrContent: 'QR-$index');
        final state = cubit.state as OperatorCheckInLoaded;
        final newest = state.recentScans.first;
        items.insert(0, newest);
        expect(newest.code, 'TK-$index');
        expect(state.recentScans, items.take(20).toList());
        expect(state.recentScans.length, index < 20 ? index : 20);
        expect(
          newest.status,
          kind == null
              ? CheckInScanStatus.valid
              : kind == CheckInFailureKind.alreadyUsed
              ? CheckInScanStatus.alreadyUsed
              : kind == CheckInFailureKind.network ||
                    kind == CheckInFailureKind.system
              ? CheckInScanStatus.notConfirmed
              : CheckInScanStatus.rejected,
        );
        // A duplicate QR must not create an extra history entry.
        await cubit.submitScan(qrContent: 'QR-$index');
        expect(
          (cubit.state as OperatorCheckInLoaded).recentScans,
          state.recentScans,
        );
      }
      repository.failureToThrow = null;
      final retained = (cubit.state as OperatorCheckInLoaded).recentScans;
      await cubit.loadInitial();
      expect((cubit.state as OperatorCheckInLoaded).recentScans, retained);
      cubit.clearActiveBanner();
      expect((cubit.state as OperatorCheckInLoaded).recentScans, retained);
      repository.departuresToReturn = [];
      await cubit.loadInitial();
      expect((cubit.state as OperatorCheckInLoaded).recentScans, retained);
    });
  }

  group('OperatorCheckInCubit - Lifecycle & Loading', () {
    test('initial state is OperatorCheckInInitial', () {
      expect(cubit.state, isA<OperatorCheckInInitial>());
    });

    test('loadInitial loads departures and default progress', () async {
      await cubit.loadInitial();

      expect(cubit.state, isA<OperatorCheckInLoaded>());
      final loaded = cubit.state as OperatorCheckInLoaded;
      expect(loaded.departures.length, 1);
      expect(loaded.selectedDeparture?.scheduleId, 101);
      expect(loaded.progress?.checkedInParticipants, 10);
      expect(repository.lastProgressScheduleId, 101);
    });

    test('loadInitial handles empty departures', () async {
      repository.departuresToReturn = [];

      await cubit.loadInitial();

      expect(cubit.state, isA<OperatorCheckInLoaded>());
      final loaded = cubit.state as OperatorCheckInLoaded;
      expect(loaded.departures, isEmpty);
      expect(loaded.selectedDeparture, isNull);
      expect(loaded.progress, isNull);
    });

    test(
      'loadInitial emits OperatorCheckInError on repository failure',
      () async {
        repository.failureToThrow = const CheckInFailure(
          kind: CheckInFailureKind.system,
          message: 'Network connection failed',
        );

        await cubit.loadInitial();

        expect(cubit.state, isA<OperatorCheckInError>());
        final error = cubit.state as OperatorCheckInError;
        expect(error.message, 'Network connection failed');
      },
    );

    test(
      'selectDeparture updates selected departure and refreshes progress',
      () async {
        repository.departuresToReturn = [
          OperatorDepartureSummary(
            scheduleId: 101,
            tourId: 1,
            tourTitle: 'Hanoi Morning Tour',
            startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
            endAtUtc: DateTime.utc(2026, 10, 30, 12, 0),
            meetingPoint: 'Opera House',
            status: 'Open',
            checkedInParticipants: 5,
            totalEligibleParticipants: 10,
            waitingParticipants: 5,
          ),
          OperatorDepartureSummary(
            scheduleId: 102,
            tourId: 2,
            tourTitle: 'Hanoi Afternoon Tour',
            startAtUtc: DateTime.utc(2026, 10, 30, 13, 0),
            endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
            meetingPoint: 'Old Quarter',
            status: 'Open',
            checkedInParticipants: 0,
            totalEligibleParticipants: 15,
            waitingParticipants: 15,
          ),
        ];

        await cubit.loadInitial();
        expect(
          (cubit.state as OperatorCheckInLoaded).selectedDeparture?.scheduleId,
          101,
        );

        repository.progressToReturn = DepartureProgress(
          scheduleId: 102,
          tourTitle: 'Hanoi Afternoon Tour',
          startAtUtc: DateTime.utc(2026, 10, 30, 13, 0),
          endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
          meetingPoint: 'Old Quarter',
          checkedInParticipants: 0,
          totalEligibleParticipants: 15,
          waitingParticipants: 15,
        );

        await cubit.selectDeparture(102);

        final loaded = cubit.state as OperatorCheckInLoaded;
        expect(loaded.selectedDeparture?.scheduleId, 102);
        expect(loaded.progress?.scheduleId, 102);
        expect(repository.lastProgressScheduleId, 102);
      },
    );

    test(
      'selectDeparture Case A: successful progress refresh syncs departures, selectedDeparture, and progress',
      () async {
        repository.departuresToReturn = [
          OperatorDepartureSummary(
            scheduleId: 101,
            tourId: 1,
            tourTitle: 'Hanoi Morning Tour',
            startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
            endAtUtc: DateTime.utc(2026, 10, 30, 12, 0),
            meetingPoint: 'Opera House',
            status: 'Open',
            checkedInParticipants: 5,
            totalEligibleParticipants: 10,
            waitingParticipants: 5,
          ),
          OperatorDepartureSummary(
            scheduleId: 102,
            tourId: 2,
            tourTitle: 'Hanoi Afternoon Tour',
            startAtUtc: DateTime.utc(2026, 10, 30, 13, 0),
            endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
            meetingPoint: 'Old Quarter',
            status: 'Open',
            checkedInParticipants: 0,
            totalEligibleParticipants: 15,
            waitingParticipants: 15,
          ),
        ];

        await cubit.loadInitial();

        repository.progressToReturn = DepartureProgress(
          scheduleId: 102,
          tourTitle: 'Hanoi Afternoon Tour',
          startAtUtc: DateTime.utc(2026, 10, 30, 13, 0),
          endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
          meetingPoint: 'Old Quarter',
          checkedInParticipants: 9,
          totalEligibleParticipants: 15,
          waitingParticipants: 6,
        );

        await cubit.selectDeparture(102);

        final loaded = cubit.state as OperatorCheckInLoaded;
        expect(loaded.progress?.checkedInParticipants, 9);
        expect(loaded.progress?.waitingParticipants, 6);
        expect(loaded.selectedDeparture?.checkedInParticipants, 9);
        expect(loaded.selectedDeparture?.waitingParticipants, 6);
        final listItem = loaded.departures.firstWhere(
          (d) => d.scheduleId == 102,
        );
        expect(listItem.checkedInParticipants, 9);
        expect(listItem.totalEligibleParticipants, 15);
        expect(listItem.waitingParticipants, 6);
      },
    );

    test(
      'selectDeparture Case B: failed progress refresh keeps newly selected departure and snapshot without crashing',
      () async {
        repository.departuresToReturn = [
          OperatorDepartureSummary(
            scheduleId: 101,
            tourId: 1,
            tourTitle: 'Hanoi Morning Tour',
            startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
            endAtUtc: DateTime.utc(2026, 10, 30, 12, 0),
            meetingPoint: 'Opera House',
            status: 'Open',
            checkedInParticipants: 5,
            totalEligibleParticipants: 10,
            waitingParticipants: 5,
          ),
          OperatorDepartureSummary(
            scheduleId: 102,
            tourId: 2,
            tourTitle: 'Hanoi Afternoon Tour',
            startAtUtc: DateTime.utc(2026, 10, 30, 13, 0),
            endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
            meetingPoint: 'Old Quarter',
            status: 'Open',
            checkedInParticipants: 3,
            totalEligibleParticipants: 15,
            waitingParticipants: 12,
          ),
        ];

        await cubit.loadInitial();
        repository.failureToThrow = const CheckInFailure(
          kind: CheckInFailureKind.invalidInput,
          message: 'Invalid schedule filter.',
        );

        await cubit.selectDeparture(102);

        final loaded = cubit.state as OperatorCheckInLoaded;
        expect(loaded.selectedDeparture?.scheduleId, 102);
        expect(loaded.selectedDeparture?.checkedInParticipants, 3);
        expect(loaded.progress?.scheduleId, 102);
        expect(loaded.progress?.checkedInParticipants, 3);
        expect(loaded.progress?.waitingParticipants, 12);
        expect(loaded.lastFailure, isNull);
      },
    );

    test(
      'selectDeparture Case C (A -> B -> A): preserves latest fetched authoritative counter even if return fetch fails',
      () async {
        repository.departuresToReturn = [
          OperatorDepartureSummary(
            scheduleId: 101,
            tourId: 1,
            tourTitle: 'Hanoi Morning Tour',
            startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
            endAtUtc: DateTime.utc(2026, 10, 30, 12, 0),
            meetingPoint: 'Opera House',
            status: 'Open',
            checkedInParticipants: 5,
            totalEligibleParticipants: 10,
            waitingParticipants: 5,
          ),
          OperatorDepartureSummary(
            scheduleId: 102,
            tourId: 2,
            tourTitle: 'Hanoi Afternoon Tour',
            startAtUtc: DateTime.utc(2026, 10, 30, 13, 0),
            endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
            meetingPoint: 'Old Quarter',
            status: 'Open',
            checkedInParticipants: 0,
            totalEligibleParticipants: 15,
            waitingParticipants: 15,
          ),
        ];

        await cubit.loadInitial();

        // Update A via successful check-in (5 -> 7)
        repository.resultToReturn = CheckInResult(
          ticketCode: 'TK-A',
          bookingCode: 'BK-A',
          passengerName: 'Pax A',
          participantCount: 2,
          checkedInAtUtc: DateTime.utc(2026, 10, 30, 8, 10),
          departure: DepartureProgress(
            scheduleId: 101,
            tourTitle: 'Hanoi Morning Tour',
            startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
            endAtUtc: DateTime.utc(2026, 10, 30, 12, 0),
            meetingPoint: 'Opera House',
            checkedInParticipants: 7,
            totalEligibleParticipants: 10,
            waitingParticipants: 3,
          ),
        );
        await cubit.submitScan(qrContent: 'QR-A');

        // Switch A -> B with authoritative progress fetch (0 -> 6)
        repository.progressToReturn = DepartureProgress(
          scheduleId: 102,
          tourTitle: 'Hanoi Afternoon Tour',
          startAtUtc: DateTime.utc(2026, 10, 30, 13, 0),
          endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
          meetingPoint: 'Old Quarter',
          checkedInParticipants: 6,
          totalEligibleParticipants: 15,
          waitingParticipants: 9,
        );
        await cubit.selectDeparture(102);

        // Switch B -> A while progress read fails: must keep A's synced 7/10, not stale 5/10
        repository.failureToThrow = const CheckInFailure(
          kind: CheckInFailureKind.network,
        );
        await cubit.selectDeparture(101);
        final backAtA = cubit.state as OperatorCheckInLoaded;
        expect(backAtA.selectedDeparture?.scheduleId, 101);
        expect(backAtA.selectedDeparture?.checkedInParticipants, 7);
        expect(backAtA.progress?.checkedInParticipants, 7);
        expect(backAtA.progress?.waitingParticipants, 3);

        // Switch A -> B again while progress read still fails: must keep B's synced 6/15, not stale 0/15
        await cubit.selectDeparture(102);
        final backAtB = cubit.state as OperatorCheckInLoaded;
        expect(backAtB.selectedDeparture?.scheduleId, 102);
        expect(backAtB.selectedDeparture?.checkedInParticipants, 6);
        expect(backAtB.progress?.checkedInParticipants, 6);
        expect(backAtB.progress?.waitingParticipants, 9);
      },
    );

    test(
      'loadInitial emits context-appropriate error on 400 invalidInput without QR/booking-code prompt',
      () async {
        repository.failureToThrow = const CheckInFailure(
          kind: CheckInFailureKind.invalidInput,
        );

        await cubit.loadInitial();

        expect(cubit.state, isA<OperatorCheckInError>());
        final error = cubit.state as OperatorCheckInError;
        expect(error.message, 'Không thể tải danh sách chuyến khởi hành');
        expect(error.message.toLowerCase(), isNot(contains('qr')));
        expect(error.message.toLowerCase(), isNot(contains('booking code')));
      },
    );

    test(
      'OperatorDepartureSummary.copyWith updates counters while preserving all other fields',
      () {
        final original = OperatorDepartureSummary(
          scheduleId: 101,
          tourId: 7,
          tourTitle: 'Hanoi Heritage Tour',
          startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
          endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
          meetingPoint: 'Opera House',
          status: 'Scheduled',
          checkedInParticipants: 2,
          totalEligibleParticipants: 10,
          waitingParticipants: 8,
        );

        final updated = original.copyWith(
          checkedInParticipants: 5,
          waitingParticipants: 5,
        );

        expect(updated.scheduleId, original.scheduleId);
        expect(updated.tourId, original.tourId);
        expect(updated.tourTitle, original.tourTitle);
        expect(updated.startAtUtc, original.startAtUtc);
        expect(updated.endAtUtc, original.endAtUtc);
        expect(updated.meetingPoint, original.meetingPoint);
        expect(updated.status, original.status);
        expect(updated.checkedInParticipants, 5);
        expect(updated.totalEligibleParticipants, 10);
        expect(updated.waitingParticipants, 5);
      },
    );
  });

  group('OperatorCheckInCubit - Scan & Verification', () {
    setUp(() async {
      await cubit.loadInitial();
    });

    test('successful scan updates progress and adds to recentScans', () async {
      await cubit.submitScan(qrContent: 'TM-QR-VALID-12345');

      expect(repository.lastScanScheduleId, 101);
      expect(repository.lastScanQrContent, 'TM-QR-VALID-12345');

      final loaded = cubit.state as OperatorCheckInLoaded;
      expect(loaded.lastResult, isNotNull);
      expect(loaded.lastResult?.ticketCode, 'TK-0000000501');
      expect(loaded.lastResult?.passengerName, 'Nguyen Van A');
      expect(loaded.lastFailure, isNull);
      expect(loaded.progress?.checkedInParticipants, 12);
      expect(loaded.selectedDeparture?.checkedInParticipants, 12);
      expect(loaded.departures.first.checkedInParticipants, 12);
      expect(loaded.departures.first.waitingParticipants, 8);
      expect(loaded.recentScans.length, 1);
      expect(loaded.recentScans.first.status, CheckInScanStatus.valid);
      expect(loaded.recentScans.first.code, 'TK-0000000501');
    });

    test(
      'already used ticket scan sets alreadyUsed failure and scan item',
      () async {
        repository.failureToThrow = CheckInFailure(
          kind: CheckInFailureKind.alreadyUsed,
          message: 'This ticket has already been checked in',
          ticketCode: 'TK-0000000501',
          passengerName: 'Nguyen Van A',
          checkedInAt: DateTime.utc(2026, 10, 30, 8, 15),
        );

        await cubit.submitScan(qrContent: 'TM-QR-ALREADY-USED');

        final loaded = cubit.state as OperatorCheckInLoaded;
        expect(loaded.lastResult, isNull);
        expect(loaded.lastFailure, isNotNull);
        expect(loaded.lastFailure?.kind, CheckInFailureKind.alreadyUsed);
        expect(loaded.recentScans.length, 1);
        expect(loaded.recentScans.first.status, CheckInScanStatus.alreadyUsed);
        expect(loaded.recentScans.first.code, 'TK-0000000501');
      },
    );

    test('wrong schedule scan sets rejected failure and scan item', () async {
      repository.failureToThrow = const CheckInFailure(
        kind: CheckInFailureKind.wrongSchedule,
        message: 'Ticket is for a different tour departure',
      );

      await cubit.submitScan(qrContent: 'TM-QR-WRONG-SCHEDULE');

      final loaded = cubit.state as OperatorCheckInLoaded;
      expect(loaded.lastResult, isNull);
      expect(loaded.lastFailure, isNotNull);
      expect(loaded.lastFailure?.kind, CheckInFailureKind.wrongSchedule);
      expect(loaded.recentScans.length, 1);
      expect(loaded.recentScans.first.status, CheckInScanStatus.rejected);
    });

    test('clearActiveBanner clears lastResult and lastFailure', () async {
      await cubit.submitScan(qrContent: 'TM-QR-VALID-12345');
      expect((cubit.state as OperatorCheckInLoaded).lastResult, isNotNull);

      cubit.clearActiveBanner();

      final cleared = cubit.state as OperatorCheckInLoaded;
      expect(cleared.lastResult, isNull);
      expect(cleared.lastFailure, isNull);
      expect(cleared.recentScans.length, 1); // Recent history preserved
    });
  });
}
