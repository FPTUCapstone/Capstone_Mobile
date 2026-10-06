import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/tour_booking_record.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/qr_eticket_cubit.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/qr_eticket_state.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/demo/demo_booking_funnel_store.dart';

void main() {
  final store = DemoBookingFunnelStore.instance;

  setUp(store.reset);

  group('QrEticketCubit (UC-29)', () {
    test(
      'production mode (!isDemoMode) emits pendingIntegration and never generates fake QR e-ticket',
      () async {
        final cubit = QrEticketCubit(
          bookingId: 'BK-PROD-1001',
          isDemoMode: false,
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, QrEticketStatus.pendingIntegration);
        expect(cubit.state.shouldRenderQrCode, isFalse);
        expect(cubit.state.eticket, isNull);
        expect(store.totalBookingsCount, 0);
      },
    );

    test(
      'demo mode loads Confirmed booking with Valid ticket (MSG93) and renders QR code',
      () async {
        final cubit = QrEticketCubit(
          bookingId: 'BK-DEMO-1001',
          isDemoMode: true,
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, QrEticketStatus.ready);
        expect(cubit.state.statusMessage, QrEticketState.msg93);
        expect(cubit.state.ticketStatus, TicketLifecycleStatus.valid);
        expect(cubit.state.shouldRenderQrCode, isTrue);
        expect(
          cubit.state.eticket?.opaqueQrPayload,
          'DEMO-QR-PAYLOAD::BK-DEMO-1001::v1',
        );
      },
    );

    test(
      'refreshQrCode updates payload version while strictly preserving current TicketLifecycleStatus (Valid, NotYetActive, Used, Cancelled, Expired)',
      () async {
        final cubit = QrEticketCubit(
          bookingId: 'BK-DEMO-1001',
          isDemoMode: true,
        );
        addTearDown(cubit.close);

        await cubit.load();

        // 1. Valid -> refresh -> stays Valid, v2
        cubit.refreshQrCode();
        expect(cubit.state.ticketStatus, TicketLifecycleStatus.valid);
        expect(cubit.state.eticket?.refreshVersion, 2);
        expect(
          cubit.state.eticket?.opaqueQrPayload,
          'DEMO-QR-PAYLOAD::BK-DEMO-1001::v2',
        );

        // 2. Used -> refresh -> stays Used, v3 (MSG95)
        cubit.simulateTicketStatus(TicketLifecycleStatus.used);
        expect(cubit.state.ticketStatus, TicketLifecycleStatus.used);
        expect(cubit.state.statusMessage, QrEticketState.msg95);
        cubit.refreshQrCode();
        expect(cubit.state.ticketStatus, TicketLifecycleStatus.used);
        expect(cubit.state.statusMessage, QrEticketState.msg95);
        expect(cubit.state.eticket?.refreshVersion, 3);

        // 3. NotYetActive -> refresh -> stays NotYetActive, v4 (MSG98)
        cubit.simulateTicketStatus(TicketLifecycleStatus.notYetActive);
        expect(cubit.state.ticketStatus, TicketLifecycleStatus.notYetActive);
        expect(cubit.state.statusMessage, QrEticketState.msg98);
        cubit.refreshQrCode();
        expect(cubit.state.ticketStatus, TicketLifecycleStatus.notYetActive);
        expect(cubit.state.statusMessage, QrEticketState.msg98);
        expect(cubit.state.eticket?.refreshVersion, 4);

        // 4. Cancelled -> refresh -> stays Cancelled, v5 (MSG74 / BR-86)
        cubit.simulateTicketStatus(TicketLifecycleStatus.cancelled);
        expect(cubit.state.ticketStatus, TicketLifecycleStatus.cancelled);
        expect(cubit.state.statusMessage, QrEticketState.msg74);
        expect(cubit.state.shouldRenderQrCode, isFalse);
        cubit.refreshQrCode();
        expect(cubit.state.ticketStatus, TicketLifecycleStatus.cancelled);
        expect(cubit.state.statusMessage, QrEticketState.msg74);
        expect(cubit.state.shouldRenderQrCode, isFalse);
        expect(cubit.state.eticket?.refreshVersion, 5);

        // 5. Expired -> refresh -> stays Expired, v6 (MSG99)
        cubit.simulateTicketStatus(TicketLifecycleStatus.expired);
        expect(cubit.state.ticketStatus, TicketLifecycleStatus.expired);
        expect(cubit.state.statusMessage, QrEticketState.msg99);
        cubit.refreshQrCode();
        expect(cubit.state.ticketStatus, TicketLifecycleStatus.expired);
        expect(cubit.state.statusMessage, QrEticketState.msg99);
        expect(cubit.state.eticket?.refreshVersion, 6);
      },
    );

    test(
      'BR-82 unconfirmed booking (MSG90), BR-90 non-owner access (MSG126), and system error (MSG127) do not render QR code',
      () async {
        final cubit = QrEticketCubit(
          bookingId: 'BK-DEMO-1001',
          isDemoMode: true,
        );
        addTearDown(cubit.close);

        await cubit.load();

        cubit.simulateUnconfirmedBooking();
        expect(cubit.state.status, QrEticketStatus.unconfirmedBooking);
        expect(cubit.state.statusMessage, QrEticketState.msg90);
        expect(cubit.state.shouldRenderQrCode, isFalse);

        cubit.resetDemoTicket();
        cubit.simulateNonOwnerAccess();
        expect(cubit.state.status, QrEticketStatus.unauthorized);
        expect(cubit.state.statusMessage, QrEticketState.msg126);
        expect(cubit.state.shouldRenderQrCode, isFalse);

        cubit.simulateSystemError();
        expect(cubit.state.status, QrEticketStatus.error);
        expect(cubit.state.errorMessage, QrEticketState.msg127);
        expect(cubit.state.shouldRenderQrCode, isFalse);
      },
    );
  });
}
