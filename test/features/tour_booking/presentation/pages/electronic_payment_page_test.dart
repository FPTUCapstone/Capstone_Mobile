import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/electronic_payment_state.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/demo/demo_booking_funnel_store.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/pages/electronic_payment_page.dart';

Widget _buildTestWidget({
  String bookingId = 'BK-DEMO-1001',
  bool isDemoMode = false,
  double textScaleFactor = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: ElectronicPaymentPage(
        bookingId: bookingId,
        isDemoMode: isDemoMode,
        enableTicker: false,
      ),
    ),
  );
}

void main() {
  setUp(DemoBookingFunnelStore.instance.reset);

  group('ElectronicPaymentPage (Screen #67 - UC-28)', () {
    testWidgets(
      'production mode (!isDemoMode) renders pending integration banner truthfully',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(bookingId: 'BK-PROD-1', isDemoMode: false),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('payment-pending-integration-banner')),
          findsOneWidget,
        );
        expect(
          find.text('Cổng thanh toán điện tử đang chờ tích hợp máy chủ'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('payment-proceed-button')), findsNothing);
        expect(DemoBookingFunnelStore.instance.totalBookingsCount, 0);
      },
    );

    testWidgets(
      'demo mode displays booking summary, 15-minute countdown, and strictly VNPay + PayOS methods',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(isDemoMode: true));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('payment-booking-summary-card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('payment-summary-booking-code')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('payment-countdown-value')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('payment-method-vnpay')), findsOneWidget);
        expect(find.byKey(const Key('payment-method-payos')), findsOneWidget);
        expect(find.text('VNPay'), findsOneWidget);
        expect(find.text('PayOS'), findsOneWidget);
      },
    );

    testWidgets(
      'gateway return simulation shows MSG90 without View QR E-ticket CTA; verified server IPN shows MSG86 and enables View QR E-ticket CTA',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(isDemoMode: true));
        await tester.pumpAndSettle();

        // Tap Gateway Return (Non-authoritative)
        final gatewayReturnChip = find.byKey(
          const Key('demo-uc28-gateway-return'),
        );
        await tester.tap(gatewayReturnChip);
        await tester.pumpAndSettle();

        expect(find.text(ElectronicPaymentState.msg90), findsOneWidget);
        expect(
          find.byKey(const Key('payment-view-eticket-button')),
          findsNothing,
        );

        // Tap Verified Server IPN
        final verifiedChip = find.byKey(
          const Key('demo-uc28-verified-success'),
        );
        await tester.tap(verifiedChip);
        await tester.pumpAndSettle();

        expect(find.text(ElectronicPaymentState.msg86), findsOneWidget);
        expect(
          find.byKey(const Key('payment-view-eticket-button')),
          findsOneWidget,
        );
      },
    );

    group('Responsive and accessibility checks (UC-28)', () {
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
          expect(find.text('Thanh toán điện tử'), findsOneWidget);
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
        expect(find.text('Thanh toán điện tử'), findsOneWidget);
      });
    });
  });
}
