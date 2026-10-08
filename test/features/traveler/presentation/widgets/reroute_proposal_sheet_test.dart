import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/reroute_proposal_sheet.dart';

void main() {
  group('RerouteProposalSheet formatArrivalTimeDiff (P2-1)', () {
    test('formats negative diff as "X min earlier"', () {
      expect(RerouteProposalSheet.formatArrivalTimeDiff(-30), '30 min earlier');
      expect(RerouteProposalSheet.formatArrivalTimeDiff(-1), '1 min earlier');
      expect(RerouteProposalSheet.formatArrivalTimeDiff(-15), '15 min earlier');
    });

    test('formats positive diff as "X min later"', () {
      expect(RerouteProposalSheet.formatArrivalTimeDiff(15), '15 min later');
      expect(RerouteProposalSheet.formatArrivalTimeDiff(1), '1 min later');
      expect(RerouteProposalSheet.formatArrivalTimeDiff(45), '45 min later');
    });

    test('formats zero diff as "No arrival-time change"', () {
      expect(
        RerouteProposalSheet.formatArrivalTimeDiff(0),
        'No arrival-time change',
      );
    });
  });

  group('RerouteProposalSheet Widget & Callbacks (P1-2, P2-1)', () {
    RerouteProposal createTestProposal({
      int arrivalTimeDiffMinutes = -30,
      int travelTimeDiffMinutes = -15,
    }) {
      return RerouteProposal(
        proposalId: 'prop-101',
        reason: 'Heavy rain detected at next stop.',
        currentStops: const ['Stop A (Heavy Rain)', 'Stop B'],
        proposedStops: const ['Stop A', 'Stop B (Indoor Shelter)'],
        travelTimeDiffMinutes: travelTimeDiffMinutes,
        arrivalTimeDiffMinutes: arrivalTimeDiffMinutes,
        affectedStops: const ['Stop A'],
        raisedAt: DateTime.now(),
      );
    }

    testWidgets('renders "30 min earlier" when arrivalTimeDiffMinutes is -30', (
      tester,
    ) async {
      final proposal = createTestProposal(arrivalTimeDiffMinutes: -30);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RerouteProposalSheet(
              proposal: proposal,
              onAccept: () {},
              onDecline: () {},
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Arrival time adjustment'), findsOneWidget);
      expect(find.text('30 min earlier'), findsOneWidget);
      expect(find.textContaining('-30 min'), findsNothing);
    });

    testWidgets('renders "15 min later" when arrivalTimeDiffMinutes is 15', (
      tester,
    ) async {
      final proposal = createTestProposal(arrivalTimeDiffMinutes: 15);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RerouteProposalSheet(
              proposal: proposal,
              onAccept: () {},
              onDecline: () {},
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Arrival time adjustment'), findsOneWidget);
      expect(find.text('15 min later'), findsOneWidget);
      expect(find.textContaining('15 min earlier'), findsNothing);
    });

    testWidgets(
      'renders "No arrival-time change" when arrivalTimeDiffMinutes is 0',
      (tester) async {
        final proposal = createTestProposal(arrivalTimeDiffMinutes: 0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RerouteProposalSheet(
                proposal: proposal,
                onAccept: () {},
                onDecline: () {},
                onClose: () {},
              ),
            ),
          ),
        );

        expect(find.text('Arrival time adjustment'), findsOneWidget);
        expect(find.text('No arrival-time change'), findsOneWidget);
      },
    );

    testWidgets('close icon calls onClose only (does not decline)', (
      tester,
    ) async {
      var acceptCalled = false;
      var declineCalled = false;
      var closeCalled = false;

      final proposal = createTestProposal();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RerouteProposalSheet(
              proposal: proposal,
              onAccept: () => acceptCalled = true,
              onDecline: () => declineCalled = true,
              onClose: () => closeCalled = true,
            ),
          ),
        ),
      );

      final closeButton = find.byTooltip('Close without changing plan');
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(closeCalled, isTrue);
      expect(declineCalled, isFalse);
      expect(acceptCalled, isFalse);
    });

    testWidgets('Keep Current Route button calls onDecline only', (
      tester,
    ) async {
      var acceptCalled = false;
      var declineCalled = false;
      var closeCalled = false;

      final proposal = createTestProposal();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RerouteProposalSheet(
              proposal: proposal,
              onAccept: () => acceptCalled = true,
              onDecline: () => declineCalled = true,
              onClose: () => closeCalled = true,
            ),
          ),
        ),
      );

      final declineButton = find.text('Keep Current Route');
      expect(declineButton, findsOneWidget);

      await tester.tap(declineButton);
      await tester.pumpAndSettle();

      expect(declineCalled, isTrue);
      expect(closeCalled, isFalse);
      expect(acceptCalled, isFalse);
    });

    testWidgets('Accept Re-routing button calls onAccept only', (tester) async {
      var acceptCalled = false;
      var declineCalled = false;
      var closeCalled = false;

      final proposal = createTestProposal();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RerouteProposalSheet(
              proposal: proposal,
              onAccept: () => acceptCalled = true,
              onDecline: () => declineCalled = true,
              onClose: () => closeCalled = true,
            ),
          ),
        ),
      );

      final acceptButton = find.text('Accept Re-routing');
      expect(acceptButton, findsOneWidget);

      await tester.tap(acceptButton);
      await tester.pumpAndSettle();

      expect(acceptCalled, isTrue);
      expect(declineCalled, isFalse);
      expect(closeCalled, isFalse);
    });
  });
}
