import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/repositories/operator_check_in_repository.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/usecases/operator_check_in_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_cubit.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/pages/operator_check_in_page.dart';

final class _FakeCheckInRepository implements OperatorCheckInRepository {
  List<OperatorDepartureSummary> departures = [];
  DepartureProgress? progress;
  CheckInResult? scanResult;
  CheckInFailure? scanFailure;
  String? lastScannedQr;
  String? lastScannedBookingCode;

  @override
  Future<List<OperatorDepartureSummary>> getTodayDepartures(
      {DateTime? targetDate}) async {
    return departures;
  }

  @override
  Future<DepartureProgress> getDepartureProgress(int scheduleId) async {
    return progress ??
        DepartureProgress(
          scheduleId: scheduleId,
          tourTitle: 'Hanoi Heritage Tour',
          startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
          endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
          meetingPoint: 'Hanoi Opera House',
          checkedInParticipants: 18,
          totalEligibleParticipants: 31,
          waitingParticipants: 13,
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
    lastScannedQr = qrContent;
    lastScannedBookingCode = bookingCode;

    if (scanFailure != null) throw scanFailure!;

    return scanResult ??
        CheckInResult(
          ticketCode: 'TK-0000000088',
          bookingCode: 'BK-20261030-088',
          passengerName: 'Tran Thi Mai',
          participantCount: 2,
          checkedInAtUtc: DateTime.utc(2026, 10, 30, 8, 30),
          departure: DepartureProgress(
            scheduleId: scheduleId,
            tourTitle: 'Hanoi Heritage Tour',
            startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
            endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
            meetingPoint: 'Hanoi Opera House',
            checkedInParticipants: 20,
            totalEligibleParticipants: 31,
            waitingParticipants: 11,
          ),
        );
  }
}

void main() {
  late _FakeCheckInRepository repository;

  setUp(() {
    repository = _FakeCheckInRepository();
  });

  Widget buildTestableWidget({
    _FakeCheckInRepository? repo,
    int? initialScheduleId,
    Widget Function(BuildContext, {required ValueChanged<String> onDetect})?
        scannerBuilder,
  }) {
    final effectiveRepo = repo ?? repository;
    return MaterialApp(
      home: BlocProvider<OperatorCheckInCubit>(
        create: (_) => OperatorCheckInCubit(
          getTodayDepartures: GetOperatorTodayDeparturesUseCase(effectiveRepo),
          getDepartureProgress: GetDepartureProgressUseCase(effectiveRepo),
          scanCheckIn: ScanCheckInUseCase(effectiveRepo),
        ),
        child: OperatorCheckInPage(
          initialScheduleId: initialScheduleId,
          scannerBuilder: scannerBuilder,
        ),
      ),
    );
  }

  testWidgets('renders empty state when no departures exist', (tester) async {
    repository.departures = [];

    await tester.pumpWidget(buildTestableWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Check-in'), findsOneWidget);
    expect(find.text('No departures scheduled for today'), findsOneWidget);
    expect(
      find.text('Check back when a tour departure is active.'),
      findsOneWidget,
    );
  });

  testWidgets('renders departure card, boarding badge and action buttons',
      (tester) async {
    repository.departures = [
      OperatorDepartureSummary(
        scheduleId: 101,
        tourId: 1,
        tourTitle: 'Hanoi Heritage Tour',
        startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
        endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
        meetingPoint: 'Hanoi Opera House',
        status: 'Open',
        checkedInParticipants: 18,
        totalEligibleParticipants: 31,
        waitingParticipants: 13,
      ),
    ];

    await tester.pumpWidget(
      buildTestableWidget(
        scannerBuilder: (context, {required onDetect}) => Container(
          key: const Key('custom_scanner_view'),
          height: 200,
          color: Colors.black,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Hanoi Heritage Tour'), findsOneWidget);
    expect(find.text('BOARDING'), findsOneWidget);
    expect(find.text('Scan next traveler'), findsOneWidget);
    expect(find.text('Manual code'), findsOneWidget);
    expect(find.byKey(const Key('custom_scanner_view')), findsOneWidget);
  });

  testWidgets('successful scan displays accepted banner', (tester) async {
    repository.departures = [
      OperatorDepartureSummary(
        scheduleId: 101,
        tourId: 1,
        tourTitle: 'Hanoi Heritage Tour',
        startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
        endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
        meetingPoint: 'Hanoi Opera House',
        status: 'Open',
        checkedInParticipants: 18,
        totalEligibleParticipants: 31,
        waitingParticipants: 13,
      ),
    ];

    late ValueChanged<String> testDetect;

    await tester.pumpWidget(
      buildTestableWidget(
        scannerBuilder: (context, {required onDetect}) {
          testDetect = onDetect;
          return const SizedBox(height: 100);
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Simulate scanning a QR code
    testDetect('VALID_QR_CODE_123');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TK-0000000088 accepted'), findsOneWidget);
    expect(find.textContaining('Tran Thi Mai · 2 pax'), findsOneWidget);
    expect(repository.lastScannedQr, 'VALID_QR_CODE_123');
  });

  testWidgets('already used scan displays warning banner with timestamp',
      (tester) async {
    repository.departures = [
      OperatorDepartureSummary(
        scheduleId: 101,
        tourId: 1,
        tourTitle: 'Hanoi Heritage Tour',
        startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
        endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
        meetingPoint: 'Hanoi Opera House',
        status: 'Open',
        checkedInParticipants: 18,
        totalEligibleParticipants: 31,
        waitingParticipants: 13,
      ),
    ];

    repository.scanFailure = CheckInFailure(
      kind: CheckInFailureKind.alreadyUsed,
      message: 'Ticket already checked in',
      ticketCode: 'TK-0000000088',
      passengerName: 'Tran Thi Mai',
      checkedInAt: DateTime.utc(2026, 10, 30, 8, 15),
    );

    late ValueChanged<String> testDetect;

    await tester.pumpWidget(
      buildTestableWidget(
        scannerBuilder: (context, {required onDetect}) {
          testDetect = onDetect;
          return const SizedBox(height: 100);
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    testDetect('REUSED_QR_CODE');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TK-0000000088 already used'), findsOneWidget);
    expect(find.textContaining('previously checked in at'), findsOneWidget);
  });

  testWidgets('manual code entry dialog opens and submits booking code',
      (tester) async {
    repository.departures = [
      OperatorDepartureSummary(
        scheduleId: 101,
        tourId: 1,
        tourTitle: 'Hanoi Heritage Tour',
        startAtUtc: DateTime.utc(2026, 10, 30, 8, 0),
        endAtUtc: DateTime.utc(2026, 10, 30, 17, 0),
        meetingPoint: 'Hanoi Opera House',
        status: 'Open',
        checkedInParticipants: 18,
        totalEligibleParticipants: 31,
        waitingParticipants: 13,
      ),
    ];

    await tester.pumpWidget(
      buildTestableWidget(
        scannerBuilder: (context, {required onDetect}) =>
            const SizedBox(height: 100),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap 'Manual code' button
    await tester.tap(find.text('Manual code'));
    await tester.pumpAndSettle();

    expect(find.text('Manual Check-in'), findsOneWidget);
    expect(find.text('Booking or Ticket Code'), findsOneWidget);

    // Enter booking code
    await tester.enterText(find.byType(TextFormField), 'BK-20261030-999');
    await tester.pump();

    // Tap 'Check In' inside dialog
    await tester.tap(find.text('Check In'));
    await tester.pumpAndSettle();

    expect(repository.lastScannedBookingCode, 'BK-20261030-999');
  });
}
