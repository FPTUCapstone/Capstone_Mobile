import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/tour_booking_state.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/demo/demo_booking_funnel_store.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/pages/tour_booking_page.dart';

Widget _buildTestWidget({
  String tourId = 'demo-tour-1',
  String? scheduleId = 'sch-001',
  bool isDemoMode = false,
  double textScaleFactor = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: TourBookingPage(
        tourId: tourId,
        scheduleId: scheduleId,
        isDemoMode: isDemoMode,
      ),
    ),
  );
}

void main() {
  setUp(DemoBookingFunnelStore.instance.reset);

  group('TourBookingPage (Screen #66 - UC-27)', () {
    testWidgets(
      'production mode (!isDemoMode) renders pending integration banner truthfully without booking form',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(tourId: 'tour-prod-1', isDemoMode: false),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('booking-pending-integration-banner')),
          findsOneWidget,
        );
        expect(
          find.text('Đặt tour trực tuyến đang chờ tích hợp máy chủ'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('booking-confirm-button')), findsNothing);
        expect(DemoBookingFunnelStore.instance.totalBookingsCount, 0);
      },
    );

    testWidgets(
      'demo mode renders summary, participant cards, contact card, voucher controls, and price breakdown',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(isDemoMode: true));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('booking-summary-card')), findsOneWidget);
        expect(
          find.byKey(const Key('booking-summary-tour-name')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('booking-summary-departure-date')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('booking-summary-return-date')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('booking-summary-unit-price')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('booking-summary-remaining-slots')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('booking-participant-card-0')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('booking-contact-card')), findsOneWidget);
        expect(find.byKey(const Key('booking-voucher-card')), findsOneWidget);
        expect(
          find.byKey(const Key('booking-price-breakdown-card')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'applying and removing voucher updates discount and total amount in UI',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(isDemoMode: true));
        await tester.pumpAndSettle();

        final voucherInput = find.byKey(const Key('booking-voucher-input'));
        await tester.ensureVisible(voucherInput);
        await tester.enterText(voucherInput, 'SUMMER2026');
        await tester.pumpAndSettle();

        final applyBtn = find.byKey(const Key('booking-apply-voucher-button'));
        await tester.ensureVisible(applyBtn);
        await tester.tap(applyBtn);
        await tester.pumpAndSettle();

        expect(find.text(TourBookingState.msg100), findsOneWidget);
        expect(find.text('-200.000₫'), findsOneWidget);
        expect(find.text('2.690.000₫'), findsOneWidget);

        final removeBtn = find.byKey(
          const Key('booking-remove-voucher-button'),
        );
        await tester.ensureVisible(removeBtn);
        await tester.tap(removeBtn);
        await tester.pumpAndSettle();

        expect(find.text(TourBookingState.msg103), findsOneWidget);
      },
    );

    group('Responsive and accessibility checks (UC-27)', () {
      final viewports = <String, Size>{
        'compact 360x640': const Size(360, 640),
        'standard 390x844': const Size(390, 844),
        'large 412x915': const Size(412, 915),
      };

      for (final entry in viewports.entries) {
        testWidgets('renders cleanly on ${entry.key}', (tester) async {
          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(_buildTestWidget(isDemoMode: true));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Đặt Tour'), findsOneWidget);
        });
      }

      testWidgets('renders without overflow at 200% font scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _buildTestWidget(isDemoMode: true, textScaleFactor: 2.0),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Đặt Tour'), findsOneWidget);
      });
    });
  });
}
