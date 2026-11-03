import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/entities/operator_check_in_models.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_departure_header.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_recent_scans_card.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/widgets/check_in_result_banner.dart';

DepartureProgress _progress(DateTime start) => DepartureProgress(
  scheduleId: 1,
  tourTitle: 'Test departure',
  startAtUtc: start,
  endAtUtc: start.add(const Duration(hours: 2)),
  checkedInParticipants: 3,
  totalEligibleParticipants: 5,
  waitingParticipants: 2,
);

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  testWidgets('success exposes authoritative result fields and Vietnam time', (
    tester,
  ) async {
    await _pump(
      tester,
      CheckInResultBanner(
        result: CheckInResult(
          ticketCode: 'TK-42',
          bookingCode: 'BK-42',
          passengerName: 'Primary Passenger',
          participantCount: 3,
          checkedInAtUtc: DateTime.utc(2026, 12, 31, 17, 5),
          departure: _progress(DateTime.utc(2026, 12, 31, 17)),
        ),
      ),
    );
    expect(find.text('Booking Code: BK-42'), findsOneWidget);
    expect(
      find.textContaining('Passenger Name: Primary Passenger'),
      findsOneWidget,
    );
    expect(find.text('Number of Participants: 3'), findsOneWidget);
    expect(find.text('Ticket Status: Used'), findsOneWidget);
    expect(find.text('Check-in Result: Success'), findsOneWidget);
    expect(find.textContaining('01/01/2027 00:05'), findsOneWidget);
    expect(find.textContaining('Contact Name'), findsNothing);
  });

  testWidgets(
    'duplicate shows known metadata without inventing participant count',
    (tester) async {
      await _pump(
        tester,
        CheckInResultBanner(
          failure: CheckInFailure(
            kind: CheckInFailureKind.alreadyUsed,
            bookingCode: 'BK-42',
            ticketCode: 'TK-42',
            passengerName: 'Primary Passenger',
            checkedInAt: DateTime.utc(2026, 1, 31, 17, 9),
          ),
        ),
      );
      expect(find.text('Booking Code: BK-42'), findsOneWidget);
      expect(find.text('Passenger Name: Primary Passenger'), findsOneWidget);
      expect(find.text('Number of Participants: Unavailable'), findsOneWidget);
      expect(find.text('Ticket Status: Used'), findsOneWidget);
      expect(find.text('Check-in Result: Already used'), findsOneWidget);
      expect(find.textContaining('01/02/2026 00:09'), findsOneWidget);
    },
  );

  testWidgets(
    'network failure reports uncertainty rather than invalid ticket',
    (tester) async {
      await _pump(
        tester,
        const CheckInResultBanner(
          failure: CheckInFailure(kind: CheckInFailureKind.network),
        ),
      );
      expect(find.text('Booking Code: Unavailable'), findsOneWidget);
      expect(find.text('Passenger Name: Unavailable'), findsOneWidget);
      expect(find.text('Number of Participants: Unavailable'), findsOneWidget);
      expect(find.text('Ticket Status: Unknown'), findsOneWidget);
      expect(find.text('Check-in Result: Not confirmed'), findsOneWidget);
      expect(find.textContaining('rejected'), findsNothing);
    },
  );

  testWidgets('cancelled booking does not invent a ticket state', (
    tester,
  ) async {
    await _pump(
      tester,
      const CheckInResultBanner(
        failure: CheckInFailure(kind: CheckInFailureKind.bookingCancelled),
      ),
    );
    expect(find.text('Ticket Status: Unknown'), findsOneWidget);
    expect(find.text('Check-in Result: Rejected'), findsOneWidget);
    expect(find.text('Number of Participants: Unavailable'), findsOneWidget);
  });

  testWidgets('uncertain recent attempt never claims rejection', (
    tester,
  ) async {
    await _pump(
      tester,
      CheckInRecentScansCard(
        scans: [
          CheckInScanItem(
            code: 'Ticket',
            passengerName: 'Traveler',
            participantCount: 0,
            timestamp: DateTime.utc(2026, 12, 31, 17, 5),
            status: CheckInScanStatus.notConfirmed,
          ),
        ],
      ),
    );
    expect(find.text('Not confirmed'), findsOneWidget);
    expect(find.textContaining('Attempt 01/01/2027 00:05'), findsOneWidget);
    expect(find.textContaining('rejected'), findsNothing);
  });

  testWidgets('recent card renders only five of twenty retained entries', (
    tester,
  ) async {
    await _pump(
      tester,
      CheckInRecentScansCard(
        scans: List.generate(
          20,
          (index) => CheckInScanItem(
            code: 'TK-$index',
            passengerName: 'Traveler $index',
            participantCount: 2,
            timestamp: DateTime.utc(2026, 10, 30),
            status: CheckInScanStatus.valid,
          ),
        ),
      ),
    );
    for (var index = 0; index < 5; index++) {
      expect(find.text('Traveler $index'), findsOneWidget);
    }
    expect(find.text('Traveler 5'), findsNothing);
    expect(find.text('Traveler 19'), findsNothing);
  });

  for (final timestamp in [
    '2026-12-31T17:05:00Z',
    '2026-12-31T12:05:00-05:00',
    '2027-01-01T02:05:00+09:00',
  ]) {
    testWidgets(
      'header and recent scans normalize equivalent instant $timestamp',
      (tester) async {
        final instant = DateTime.parse(timestamp);
        await _pump(
          tester,
          Column(
            children: [
              CheckInDepartureHeader(progress: _progress(instant)),
              CheckInRecentScansCard(
                scans: [
                  CheckInScanItem(
                    code: 'TK-42',
                    passengerName: 'Primary Passenger',
                    participantCount: 3,
                    timestamp: instant,
                    status: CheckInScanStatus.valid,
                  ),
                ],
              ),
            ],
          ),
        );
        expect(find.text('01/01/2027 00:05'), findsOneWidget);
        expect(find.text('3 pax · 01/01/2027 00:05'), findsOneWidget);
      },
    );
  }
}
