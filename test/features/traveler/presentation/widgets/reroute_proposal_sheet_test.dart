import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/widgets/reroute_proposal_sheet.dart';

import '../../../../support/trip_alert_test_data.dart';

void main() {
  group('RerouteProposalSheet formatArrivalTimeDiff', () {
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

  group('RerouteProposalSheet reasonText', () {
    String reason(String code, {String? poi}) =>
        RerouteProposalSheet.reasonText(
          RerouteReason(code: code, strategy: 'Drop', affectedPoiName: poi),
        );

    test('explains each alert code with the affected place', () {
      expect(
        reason('trip_alert.severe_weather', poi: 'Han Market'),
        'Severe weather is expected at Han Market.',
      );
      expect(
        reason('trip_alert.poi_closure', poi: 'Cham Museum'),
        'Cham Museum is closed.',
      );
      expect(
        reason('trip_alert.schedule_delay'),
        'Your trip is running behind schedule.',
      );
      expect(
        reason('trip_alert.route_deviation'),
        'You have left the planned route.',
      );
    });

    test('falls back when the place or the code is unknown', () {
      expect(reason('trip_alert.poi_closure'), 'Your next stop is closed.');
      expect(
        reason('trip_alert.severe_weather', poi: '  '),
        'Severe weather is expected at your next stop.',
      );
      expect(reason('something.else'), 'Your plan needs a change.');
    });
  });

  group('RerouteProposalSheet widget', () {
    Future<void> pumpSheet(
      WidgetTester tester, {
      RerouteProposal? proposal,
      VoidCallback? onAccept,
      VoidCallback? onDecline,
      VoidCallback? onClose,
    }) {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RerouteProposalSheet(
              proposal: proposal ?? TripAlertTestData.sampleRerouteProposal(),
              onAccept: onAccept ?? () {},
              onDecline: onDecline ?? () {},
              onClose: onClose ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('shows the reason, both plans and what changed', (
      tester,
    ) async {
      await pumpSheet(tester);

      expect(
        find.text('Severe weather is expected at Chợ Hàn.'),
        findsOneWidget,
      );
      expect(find.text('Helio Center'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Moved'), findsOneWidget);
      expect(find.text('Removed from your plan: Chợ Hàn'), findsOneWidget);
      expect(find.text('Chợ Hàn'), findsOneWidget);
    });

    testWidgets('renders "Sớm hơn 30 phút" when arrival diff is -30', (
      tester,
    ) async {
      await pumpSheet(tester);

      expect(find.text('Điều chỉnh giờ đến'), findsOneWidget);
      expect(find.text('Sớm hơn 30 phút'), findsOneWidget);
      expect(find.text('-15 phút'), findsOneWidget);
      expect(find.textContaining('Demo'), findsNothing);
    });

    testWidgets('renders "Trễ hơn 15 phút" when arrival diff is 15', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        proposal: TripAlertTestData.sampleRerouteProposal(
          arrivalTimeDiffMinutes: 15,
        ),
      );

      expect(find.text('Điều chỉnh giờ đến'), findsOneWidget);
      expect(find.text('Trễ hơn 15 phút'), findsOneWidget);
      expect(find.textContaining('Sớm hơn 15 phút'), findsNothing);
    });

    testWidgets('renders "Không đổi giờ đến" when arrival diff is 0', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        proposal: TripAlertTestData.sampleRerouteProposal(
          arrivalTimeDiffMinutes: 0,
        ),
      );

      expect(find.text('Điều chỉnh giờ đến'), findsOneWidget);
      expect(find.text('Không đổi giờ đến'), findsOneWidget);
    });

    testWidgets('close icon calls onClose only', (tester) async {
      final calls = <String>[];
      await pumpSheet(
        tester,
        onAccept: () => calls.add('accept'),
        onDecline: () => calls.add('decline'),
        onClose: () => calls.add('close'),
      );

      await tester.tap(find.byTooltip('Đóng mà không đổi lịch trình'));

      expect(calls, ['close']);
    });

    testWidgets('Giữ lộ trình hiện tại calls onDecline only', (tester) async {
      final calls = <String>[];
      await pumpSheet(
        tester,
        onAccept: () => calls.add('accept'),
        onDecline: () => calls.add('decline'),
        onClose: () => calls.add('close'),
      );

      await tester.tap(find.text('Giữ lộ trình hiện tại'));

      expect(calls, ['decline']);
    });

    testWidgets('Chấp nhận đổi lộ trình calls onAccept only', (tester) async {
      final calls = <String>[];
      await pumpSheet(
        tester,
        onAccept: () => calls.add('accept'),
        onDecline: () => calls.add('decline'),
        onClose: () => calls.add('close'),
      );

      await tester.tap(find.text('Chấp nhận đổi lộ trình'));

      expect(calls, ['accept']);
    });
  });
}
