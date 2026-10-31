import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/repositories/operator_check_in_repository.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/usecases/operator_check_in_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_cubit.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_state.dart';

OperatorDepartureSummary _departure(int id) => OperatorDepartureSummary(
  scheduleId: id,
  tourId: id,
  tourTitle: 'Departure $id',
  startAtUtc: DateTime.utc(2026, 10, 30, 1),
  endAtUtc: DateTime.utc(2026, 10, 30, 9),
  status: 'Open',
  checkedInParticipants: id,
  totalEligibleParticipants: 20,
  waitingParticipants: 20 - id,
);

DepartureProgress _progress(int id, {int? checkedIn}) => DepartureProgress(
  scheduleId: id,
  tourTitle: 'Departure $id',
  startAtUtc: DateTime.utc(2026, 10, 30, 1),
  endAtUtc: DateTime.utc(2026, 10, 30, 9),
  checkedInParticipants: checkedIn ?? id,
  totalEligibleParticipants: 20,
  waitingParticipants: 20 - (checkedIn ?? id),
);

CheckInResult _result(int id) => CheckInResult(
  ticketCode: 'TK-$id',
  bookingCode: 'BK-$id',
  passengerName: 'Traveler $id',
  participantCount: 2,
  checkedInAtUtc: DateTime.utc(2026, 10, 30, 1),
  departure: _progress(id, checkedIn: 12),
);

final class _ControlledRepository implements OperatorCheckInRepository {
  final progressRequests = <int, Completer<DepartureProgress>>{};
  Completer<List<OperatorDepartureSummary>>? listRequest;
  Completer<CheckInResult>? scanRequest;
  int listCalls = 0;
  int scanCalls = 0;

  @override
  Future<List<OperatorDepartureSummary>> getTodayDepartures({
    DateTime? targetDate,
  }) async {
    listCalls++;
    return listRequest?.future ?? [_departure(1), _departure(2), _departure(3)];
  }

  @override
  Future<DepartureProgress> getDepartureProgress(int scheduleId) async =>
      progressRequests[scheduleId]?.future ?? _progress(scheduleId);

  @override
  Future<CheckInResult> scanCheckIn({
    required int scheduleId,
    String? qrContent,
    String? bookingCode,
    double? latitude,
    double? longitude,
  }) async {
    scanCalls++;
    return scanRequest?.future ?? _result(scheduleId);
  }
}

void main() {
  late _ControlledRepository repository;
  late OperatorCheckInCubit cubit;

  OperatorCheckInLoaded loaded() => cubit.state as OperatorCheckInLoaded;

  setUp(() async {
    repository = _ControlledRepository();
    cubit = OperatorCheckInCubit(
      getTodayDepartures: GetOperatorTodayDeparturesUseCase(repository),
      getDepartureProgress: GetDepartureProgressUseCase(repository),
      scanCheckIn: ScanCheckInUseCase(repository),
    );
    await cubit.loadInitial();
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  for (final bFinishesLast in [true, false]) {
    test(
      'latest selection wins when B finishes last: $bFinishesLast',
      () async {
        final b = Completer<DepartureProgress>();
        final c = Completer<DepartureProgress>();
        repository.progressRequests.addAll({2: b, 3: c});
        final selectingB = cubit.selectDeparture(2);
        final selectingC = cubit.selectDeparture(3);

        expect(loaded().selectedDeparture?.scheduleId, 3);
        expect(loaded().progress?.scheduleId, 3);
        if (bFinishesLast) {
          c.complete(_progress(3, checkedIn: 8));
          await selectingC;
          b.complete(_progress(2, checkedIn: 6));
          await selectingB;
        } else {
          b.complete(_progress(2, checkedIn: 6));
          await selectingB;
          c.complete(_progress(3, checkedIn: 8));
          await selectingC;
        }

        expect(loaded().selectedDeparture?.scheduleId, 3);
        expect(loaded().progress?.scheduleId, 3);
        expect(loaded().progress?.checkedInParticipants, 8);
      },
    );
  }

  test('failed progress keeps the newly selected departure snapshot', () async {
    final pending = Completer<DepartureProgress>();
    repository.progressRequests[2] = pending;
    final selection = cubit.selectDeparture(2);
    pending.completeError(
      const CheckInFailure(kind: CheckInFailureKind.network),
    );
    await selection;

    expect(loaded().selectedDeparture?.scheduleId, 2);
    expect(loaded().progress?.scheduleId, 2);
    expect(loaded().progress?.checkedInParticipants, 2);
  });

  test(
    'old progress failure cannot alter the latest successful selection',
    () async {
      final b = Completer<DepartureProgress>();
      repository.progressRequests[2] = b;
      final selectingB = cubit.selectDeparture(2);
      await cubit.selectDeparture(3);
      b.completeError(const CheckInFailure(kind: CheckInFailureKind.network));
      await selectingB;

      expect(loaded().selectedDeparture?.scheduleId, 3);
      expect(loaded().progress?.scheduleId, 3);
    },
  );

  test('wrong-schedule progress is never displayed for a selection', () async {
    final pending = Completer<DepartureProgress>();
    repository.progressRequests[2] = pending;
    final selection = cubit.selectDeparture(2);
    pending.complete(_progress(3));
    await selection;

    expect(loaded().selectedDeparture?.scheduleId, 2);
    expect(loaded().progress?.scheduleId, 2);
  });

  test('selection waits for pending scan without losing its result', () async {
    final pending = Completer<CheckInResult>();
    repository.scanRequest = pending;
    final scan = cubit.submitScan(qrContent: 'QR-1');
    await cubit.selectDeparture(2);
    expect(loaded().selectedDeparture?.scheduleId, 1);
    expect(loaded().isSubmittingScan, isTrue);
    pending.complete(_result(1));
    await scan;

    expect(loaded().selectedDeparture?.scheduleId, 1);
    expect(loaded().lastResult?.ticketCode, 'TK-1');
    expect(loaded().recentScans.single.code, 'TK-1');
    await cubit.selectDeparture(2);
    expect(loaded().selectedDeparture?.scheduleId, 2);
  });

  test(
    'refresh cannot clear scan guard or permit a duplicate submission',
    () async {
      final pending = Completer<CheckInResult>();
      repository.scanRequest = pending;
      final scan = cubit.submitScan(bookingCode: 'BK-1');
      await cubit.loadInitial(preselectedScheduleId: 2);
      final duplicate = cubit.submitScan(bookingCode: 'BK-1');

      expect(repository.listCalls, 1);
      expect(repository.scanCalls, 1);
      expect(loaded().isSubmittingScan, isTrue);
      pending.complete(_result(1));
      await scan;
      await duplicate;

      expect(loaded().lastResult?.bookingCode, 'BK-1');
      expect(loaded().isSubmittingScan, isFalse);
      await cubit.loadInitial(preselectedScheduleId: 2);
      expect(repository.listCalls, 2);
      expect(loaded().selectedDeparture?.scheduleId, 2);
    },
  );

  test(
    'selection and refresh attempts preserve a pending scan failure',
    () async {
      final pending = Completer<CheckInResult>();
      repository.scanRequest = pending;
      final scan = cubit.submitScan(bookingCode: 'BK-1');
      await cubit.selectDeparture(2);
      await cubit.loadInitial();
      pending.completeError(
        const CheckInFailure(
          kind: CheckInFailureKind.alreadyUsed,
          ticketCode: 'TK-1',
        ),
      );
      await scan;

      expect(loaded().selectedDeparture?.scheduleId, 1);
      expect(loaded().lastFailure?.kind, CheckInFailureKind.alreadyUsed);
      expect(loaded().recentScans.single.status, CheckInScanStatus.alreadyUsed);
      expect(loaded().isSubmittingScan, isFalse);
    },
  );

  test(
    'pre-scan progress cannot overwrite newer successful scan progress',
    () async {
      final pending = Completer<DepartureProgress>();
      repository.progressRequests[1] = pending;
      final selection = cubit.selectDeparture(1);
      await cubit.submitScan(qrContent: 'QR-1');
      pending.complete(_progress(1, checkedIn: 1));
      await selection;

      expect(loaded().progress?.checkedInParticipants, 12);
      expect(loaded().lastResult?.ticketCode, 'TK-1');
    },
  );

  test('no scan can start while a departure refresh is active', () async {
    final pending = Completer<List<OperatorDepartureSummary>>();
    repository.listRequest = pending;
    final refreshing = cubit.loadInitial();
    await cubit.submitScan(qrContent: 'QR-1');
    await cubit.submitScan(bookingCode: 'BK-1');
    expect(repository.scanCalls, 0);
    pending.complete([_departure(1)]);
    await refreshing;
    expect(loaded().selectedDeparture?.scheduleId, 1);
  });

  test('scan completion preserves newer camera state', () async {
    final pending = Completer<CheckInResult>();
    repository.scanRequest = pending;
    final scan = cubit.submitScan(qrContent: 'QR-1');
    cubit.setCameraPermission(false);
    pending.complete(_result(1));
    await scan;

    expect(loaded().cameraPermissionGranted, isFalse);
    expect(loaded().lastResult?.ticketCode, 'TK-1');
  });

  test('older refresh completion cannot replace a newer refresh', () async {
    final first = Completer<List<OperatorDepartureSummary>>();
    repository.listRequest = first;
    final firstRefresh = cubit.loadInitial(preselectedScheduleId: 2);
    final second = Completer<List<OperatorDepartureSummary>>();
    repository.listRequest = second;
    final secondRefresh = cubit.loadInitial(preselectedScheduleId: 3);
    second.complete([_departure(1), _departure(2), _departure(3)]);
    await secondRefresh;
    first.complete([_departure(1), _departure(2)]);
    await firstRefresh;

    expect(loaded().selectedDeparture?.scheduleId, 3);
    expect(loaded().progress?.scheduleId, 3);
  });

  test(
    'wrong-schedule scan response does not fabricate successful feedback',
    () async {
      final pending = Completer<CheckInResult>();
      repository.scanRequest = pending;
      final scan = cubit.submitScan(qrContent: 'QR-1');
      pending.complete(_result(2));
      await scan;

      expect(loaded().selectedDeparture?.scheduleId, 1);
      expect(loaded().progress?.scheduleId, 1);
      expect(loaded().lastResult, isNull);
      expect(loaded().lastFailure?.kind, CheckInFailureKind.system);
    },
  );

  test('list completion after close is harmless', () async {
    final pending = Completer<List<OperatorDepartureSummary>>();
    repository.listRequest = pending;
    final loading = cubit.loadInitial();
    await cubit.close();
    pending.complete([_departure(1)]);
    await expectLater(loading, completes);
  });

  test('progress completion after close is harmless', () async {
    final pending = Completer<DepartureProgress>();
    repository.progressRequests[2] = pending;
    final selection = cubit.selectDeparture(2);
    await cubit.close();
    pending.complete(_progress(2));
    await expectLater(selection, completes);
  });

  for (final fails in [false, true]) {
    test('scan completion after close is harmless, failure: $fails', () async {
      final pending = Completer<CheckInResult>();
      repository.scanRequest = pending;
      final scan = cubit.submitScan(qrContent: 'QR-1');
      await cubit.close();
      if (fails) {
        pending.completeError(
          const CheckInFailure(kind: CheckInFailureKind.network),
        );
      } else {
        pending.complete(_result(1));
      }
      await expectLater(scan, completes);
    });
  }
}
