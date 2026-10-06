import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/qr_eticket_state.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/demo/demo_booking_funnel_store.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/pages/qr_eticket_page.dart';

Widget _buildTestWidget({
  String bookingId = 'BK-DEMO-1001',
  bool isDemoMode = false,
  double textScaleFactor = 1.0,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: QrEticketPage(bookingId: bookingId, isDemoMode: isDemoMode),
    ),
  );
}

void main() {
  setUp(DemoBookingFunnelStore.instance.reset);

  group('QrEticketPage (Screen #69 - UC-29)', () {
    testWidgets(
      'production mode (!isDemoMode) renders pending integration banner and zero QrImageView',
      (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(bookingId: 'BK-PROD-1', isDemoMode: false),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('eticket-pending-integration-banner')),
          findsOneWidget,
        );
        expect(find.byType(QrImageView), findsNothing);
        expect(DemoBookingFunnelStore.instance.totalBookingsCount, 0);
      },
    );

    testWidgets(
      'demo mode displays QR code, Booking Code, Tour Name, Operator Name, Departure Date, Meeting Point, Participants, Ticket Status, and Refresh QR Code',
      (tester) async {
        await tester.pumpWidget(_buildTestWidget(isDemoMode: true));
        await tester.pumpAndSettle();

        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text(QrEticketState.msg93), findsOneWidget);
        expect(
          find.byKey(const Key('eticket-detail-booking-code')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('eticket-detail-tour-name')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('eticket-detail-operator-name')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('eticket-detail-departure-date')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('eticket-detail-meeting-point')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('eticket-detail-participant-count')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('eticket-detail-ticket-status')),
          findsOneWidget,
        );
        expect(find.text('Phiên bản mã: v1'), findsOneWidget);

        // Tap Refresh QR Code
        final refreshBtn = find.byKey(const Key('eticket-refresh-qr-button'));
        await tester.ensureVisible(refreshBtn);
        await tester.tap(refreshBtn);
        await tester.pumpAndSettle();

        expect(find.text('Phiên bản mã: v2'), findsOneWidget);
      },
    );

    group('Responsive and accessibility checks (UC-29)', () {
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
          expect(find.text('Vé điện tử QR (E-ticket)'), findsOneWidget);
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
        expect(find.text('Vé điện tử QR (E-ticket)'), findsOneWidget);
      });
    });
  });
}
