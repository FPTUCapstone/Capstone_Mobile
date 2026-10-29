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
  Future<List<OperatorDepartureSummary>> getTodayDepartures(
      {DateTime? targetDate}) async {
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

    test('loadInitial emits OperatorCheckInError on repository failure',
        () async {
      repository.failureToThrow = const CheckInFailure(
        kind: CheckInFailureKind.system,
        message: 'Network connection failed',
      );

      await cubit.loadInitial();

      expect(cubit.state, isA<OperatorCheckInError>());
      final error = cubit.state as OperatorCheckInError;
      expect(error.message, 'Network connection failed');
    });

    test('selectDeparture updates selected departure and refreshes progress',
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
      expect((cubit.state as OperatorCheckInLoaded).selectedDeparture?.scheduleId,
          101);

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
    });
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
      expect(loaded.recentScans.length, 1);
      expect(loaded.recentScans.first.status, CheckInScanStatus.valid);
      expect(loaded.recentScans.first.code, 'TK-0000000501');
    });

    test('already used ticket scan sets alreadyUsed failure and scan item',
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
    });

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
