import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/reroute_proposal_sheet.dart';

void main() {
  group('RerouteProposalSheet formatArrivalTimeDiff (P2-1)', () {
    test('formats negative diff as "Sớm hơn X phút"', () {
      expect(
        RerouteProposalSheet.formatArrivalTimeDiff(-30),
        'Sớm hơn 30 phút',
      );
      expect(RerouteProposalSheet.formatArrivalTimeDiff(-1), 'Sớm hơn 1 phút');
      expect(
        RerouteProposalSheet.formatArrivalTimeDiff(-15),
        'Sớm hơn 15 phút',
      );
    });

    test('formats positive diff as "Trễ hơn X phút"', () {
      expect(RerouteProposalSheet.formatArrivalTimeDiff(15), 'Trễ hơn 15 phút');
      expect(RerouteProposalSheet.formatArrivalTimeDiff(1), 'Trễ hơn 1 phút');
      expect(RerouteProposalSheet.formatArrivalTimeDiff(45), 'Trễ hơn 45 phút');
    });

    test('formats zero diff as "Không đổi giờ đến"', () {
      expect(
        RerouteProposalSheet.formatArrivalTimeDiff(0),
        'Không đổi giờ đến',
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

    testWidgets(
      'renders "Sớm hơn 30 phút" when arrivalTimeDiffMinutes is -30',
      (tester) async {
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

        expect(find.text('Điều chỉnh giờ đến'), findsOneWidget);
        expect(find.text('Sớm hơn 30 phút'), findsOneWidget);
        expect(find.textContaining('-30 phút'), findsNothing);
      },
    );

    testWidgets('renders "Trễ hơn 15 phút" when arrivalTimeDiffMinutes is 15', (
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

      expect(find.text('Điều chỉnh giờ đến'), findsOneWidget);
      expect(find.text('Trễ hơn 15 phút'), findsOneWidget);
      expect(find.textContaining('Sớm hơn 15 phút'), findsNothing);
    });

    testWidgets(
      'renders "Không đổi giờ đến" when arrivalTimeDiffMinutes is 0',
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

        expect(find.text('Điều chỉnh giờ đến'), findsOneWidget);
        expect(find.text('Không đổi giờ đến'), findsOneWidget);
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

      final closeButton = find.byTooltip('Đóng mà không đổi lịch trình');
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

      final declineButton = find.text('Giữ lộ trình hiện tại');
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

      final acceptButton = find.text('Chấp nhận đổi lộ trình');
      expect(acceptButton, findsOneWidget);

      await tester.tap(acceptButton);
      await tester.pumpAndSettle();

      expect(acceptCalled, isTrue);
      expect(declineCalled, isFalse);
      expect(closeCalled, isFalse);
    });
  });
}
