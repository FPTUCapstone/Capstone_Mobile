import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/repositories/operator_check_in_repository.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/usecases/operator_check_in_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_cubit.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_state.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/pages/operator_check_in_page.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_camera_scanner_view.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';

DepartureProgress _progress(int id, {DateTime? start}) => DepartureProgress(
  scheduleId: id,
  tourTitle: 'Departure $id',
  startAtUtc: start ?? DateTime.utc(2026, 12, 31, 17),
  endAtUtc: (start ?? DateTime.utc(2026, 12, 31, 17)).add(
    const Duration(hours: 2),
  ),
  checkedInParticipants: 2,
  totalEligibleParticipants: 10,
  waitingParticipants: 8,
);

final class _Repository implements OperatorCheckInRepository {
  int scanCalls = 0;
  CheckInFailure? failure;
  Completer<CheckInResult>? pending;
  final submittedCodes = <String>[];
  final submittedSchedules = <int>[];
  List<int> availableSchedules = [1, 2];
  final departureStarts = <int, DateTime>{};

  DateTime startFor(int id) => departureStarts[id] ?? _progress(id).startAtUtc;

  @override
  Future<List<OperatorDepartureSummary>> getTodayDepartures({
    DateTime? targetDate,
  }) async => availableSchedules
      .map(
        (id) => OperatorDepartureSummary(
          scheduleId: id,
          tourId: id,
          tourTitle: 'Departure $id',
          startAtUtc: startFor(id),
          endAtUtc: startFor(id).add(const Duration(hours: 2)),
          status: 'Open',
          checkedInParticipants: 0,
          totalEligibleParticipants: 10,
          waitingParticipants: 10,
        ),
      )
      .toList();

  @override
  Future<DepartureProgress> getDepartureProgress(int scheduleId) async =>
      _progress(scheduleId, start: startFor(scheduleId));

  @override
  Future<CheckInResult> scanCheckIn({
    required int scheduleId,
    String? qrContent,
    String? bookingCode,
    double? latitude,
    double? longitude,
  }) async {
    scanCalls++;
    submittedSchedules.add(scheduleId);
    submittedCodes.add(qrContent ?? bookingCode ?? '');
    if (pending != null) return pending!.future;
    if (failure != null) throw failure!;
    return result(scheduleId);
  }

  CheckInResult result(int id) => CheckInResult(
    ticketCode: 'TK-$scanCalls',
    bookingCode: 'BK-$scanCalls',
    passengerName: 'Passenger',
    participantCount: 2,
    checkedInAtUtc: DateTime.utc(2026, 10, 31, 1, 23),
    departure: _progress(id, start: startFor(id)),
  );
}

void main() {
  late _Repository repository;
  late OperatorCheckInCubit cubit;
  late ValueChanged<String> detect;

  Future<void> mount(WidgetTester tester) async {
    cubit = OperatorCheckInCubit(
      getTodayDepartures: GetOperatorTodayDeparturesUseCase(repository),
      getDepartureProgress: GetDepartureProgressUseCase(repository),
      scanCheckIn: ScanCheckInUseCase(repository),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: OperatorCheckInPage(
            scannerBuilder: (context, {required onDetect}) {
              detect = onDetect;
              return const SizedBox(key: Key('scanner-preview'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> beyondDebounce(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1600)),
    );
    await tester.pump();
  }

  testWidgets('departure selector displays Vietnam date and 24-hour clock', (
    tester,
  ) async {
    await mount(tester);
    final selector = find.byType(DropdownButton<int>);
    expect(
      find.descendant(
        of: selector,
        matching: find.text('01/01/2027 00:00 · Departure 1'),
      ),
      findsOneWidget,
    );
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(find.text('01/01/2027 00:00 · Departure 2'), findsOneWidget);
  });

  setUp(() => repository = _Repository());
  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });

  testWidgets(
    'same presentation is admitted only once before explicit Scan Next',
    (tester) async {
      await mount(tester);
      final scannerState = tester.state(find.byType(CheckInCameraScannerView));
      detect('QR-A');
      detect('QR-A');
      await tester.pumpAndSettle();
      expect(repository.scanCalls, 1);
      expect(
        (cubit.state as OperatorCheckInLoaded).recentScans.single.timestamp,
        DateTime.utc(2026, 10, 31, 1, 23),
      );
      await beyondDebounce(tester);
      detect('QR-A');
      detect('QR-B');
      await tester.pumpAndSettle();
      expect(repository.scanCalls, 1);
      expect((cubit.state as OperatorCheckInLoaded).lastResult, isNotNull);
      await tester.tap(find.text('Scan next traveler'));
      await tester.pumpAndSettle();
      detect('QR-B');
      await tester.pumpAndSettle();
      expect(repository.submittedCodes, ['QR-A', 'QR-B']);
      expect(
        tester.state(find.byType(CheckInCameraScannerView)),
        same(scannerState),
      );
    },
  );

  for (final kind in [
    CheckInFailureKind.network,
    CheckInFailureKind.alreadyUsed,
  ]) {
    testWidgets('$kind feedback is held until explicit Scan Next', (
      tester,
    ) async {
      repository.failure = CheckInFailure(
        kind: kind,
        message: 'Check-in outcome',
      );
      await mount(tester);
      detect('QR-A');
      await tester.pumpAndSettle();
      await beyondDebounce(tester);
      detect('QR-A');
      await tester.pumpAndSettle();
      expect(repository.scanCalls, 1);
      expect((cubit.state as OperatorCheckInLoaded).lastFailure?.kind, kind);
      if (kind == CheckInFailureKind.network) {
        expect(
          (cubit.state as OperatorCheckInLoaded).recentScans.single.status,
          CheckInScanStatus.notConfirmed,
        );
      }
      await tester.tap(find.text('Scan next traveler'));
      await tester.pumpAndSettle();
      detect('QR-A');
      await tester.pumpAndSettle();
      expect(repository.scanCalls, 2);
    });
  }

  testWidgets('manual cancellation preserves the prior armed or held session', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Manual code'));
    // Callback before the Bloc rebuild must neither submit nor consume the latch.
    detect('CAMERA-OVERLAP');
    await tester.pumpAndSettle();
    expect(repository.scanCalls, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    detect('QR-A');
    await tester.pumpAndSettle();
    expect(repository.scanCalls, 1);
    final result = (cubit.state as OperatorCheckInLoaded).lastResult;
    await tester.tap(find.text('Manual code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    detect('QR-B');
    await tester.pumpAndSettle();
    expect(repository.scanCalls, 1);
    expect((cubit.state as OperatorCheckInLoaded).lastResult, result);
  });

  testWidgets(
    'manual dialog excludes camera callbacks through request completion',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('Manual code'));
      await tester.pumpAndSettle();
      detect('CAMERA');
      await tester.pumpAndSettle();
      expect(repository.scanCalls, 0);
      repository.pending = Completer<CheckInResult>();
      await tester.enterText(find.byType(TextFormField), 'BK-MANUAL');
      await tester.tap(find.text('Check In'));
      await tester.pumpAndSettle();
      detect('CAMERA');
      await tester.pump();
      expect(repository.submittedCodes, ['BK-MANUAL']);
      repository.pending!.complete(repository.result(1));
      await tester.pumpAndSettle();
      await beyondDebounce(tester);
      detect('CAMERA');
      await tester.pumpAndSettle();
      expect(repository.scanCalls, 1);
    },
  );

  testWidgets(
    'refresh preserves held result and explicit departure switch re-arms',
    (tester) async {
      await mount(tester);
      detect('QR-A');
      await tester.pumpAndSettle();
      final accepted = (cubit.state as OperatorCheckInLoaded).lastResult;
      await tester.tap(find.byTooltip('Refresh departures'));
      await tester.pumpAndSettle();
      expect((cubit.state as OperatorCheckInLoaded).lastResult, accepted);
      await beyondDebounce(tester);
      detect('QR-A');
      await tester.pumpAndSettle();
      expect(repository.scanCalls, 1);
      await cubit.selectDeparture(2);
      await tester.pumpAndSettle();
      detect('QR-B');
      await tester.pumpAndSettle();
      expect(repository.submittedCodes, ['QR-A', 'QR-B']);
      expect(
        (cubit.state as OperatorCheckInLoaded).lastResult?.departure.scheduleId,
        2,
      );
    },
  );

  testWidgets(
    'midnight refresh requires explicit selection even when only B is available',
    (tester) async {
      repository.availableSchedules = [1];
      repository.departureStarts.addAll({
        1: DateTime.utc(2026, 12, 31, 16, 59),
        2: DateTime.utc(2026, 12, 31, 17),
      });
      await mount(tester);
      detect('QR-A');
      await tester.pumpAndSettle();
      final accepted = (cubit.state as OperatorCheckInLoaded).lastResult;

      // Simulate the server rolling its Vietnam calendar-day list forward.
      repository.availableSchedules = [2];
      await tester.tap(find.byTooltip('Refresh departures'));
      await tester.pumpAndSettle();
      final refreshed = cubit.state as OperatorCheckInLoaded;
      expect(refreshed.departures.map((d) => d.scheduleId), [2]);
      expect(refreshed.selectedDeparture, isNull);
      expect(refreshed.progress, isNull);
      expect(refreshed.lastResult, accepted);
      expect(find.text('Booking Code: BK-1'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppButton &&
              widget.label == 'Manual code' &&
              widget.onPressed != null,
        ),
        findsNothing,
      );
      detect('STALE');
      await tester.pumpAndSettle();
      expect(repository.submittedSchedules, [1]);

      final dropdown = find.byType(DropdownButton<int>);
      expect(tester.widget<DropdownButton<int>>(dropdown).value, isNull);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('01/01/2027 00:00 · Departure 2').last);
      await tester.pumpAndSettle();
      expect(find.text('Booking Code: BK-1'), findsNothing);
      detect('QR-B');
      detect('QR-B');
      await tester.pumpAndSettle();
      expect(repository.submittedCodes, ['QR-A', 'QR-B']);
      expect(repository.submittedSchedules, [1, 2]);
    },
  );

  testWidgets(
    'empty refresh shows the empty state and blocks stale callbacks',
    (tester) async {
      await mount(tester);
      detect('QR-A');
      await tester.pumpAndSettle();
      final held = cubit.state as OperatorCheckInLoaded;
      repository.availableSchedules = [];
      await tester.tap(find.byTooltip('Refresh departures'));
      await tester.pumpAndSettle();

      final refreshed = cubit.state as OperatorCheckInLoaded;
      expect(find.text('No departures scheduled for today'), findsOneWidget);
      expect(refreshed.selectedDeparture, isNull);
      expect(refreshed.progress, isNull);
      expect(refreshed.lastResult, held.lastResult);
      expect(refreshed.recentScans, held.recentScans);
      expect(find.text('Booking Code: BK-1'), findsOneWidget);
      expect(find.text('Recent scans'), findsOneWidget);
      expect(find.text('Manual code'), findsNothing);
      detect('STALE');
      await tester.pumpAndSettle();
      expect(repository.submittedSchedules, [1]);
    },
  );

  testWidgets(
    'route disposal ignores old callback and new entry has a fresh session',
    (tester) async {
      await mount(tester);
      detect('QR-A');
      await tester.pumpAndSettle();
      final oldDetect = detect;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await cubit.close();
      oldDetect('STALE');
      expect(repository.scanCalls, 1);
      await mount(tester);
      detect('QR-B');
      await tester.pumpAndSettle();
      expect(repository.submittedCodes, ['QR-A', 'QR-B']);
      expect(tester.takeException(), isNull);
    },
  );
}
