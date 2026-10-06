import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/tour_booking_record.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/electronic_payment_cubit.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/electronic_payment_state.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/demo/demo_booking_funnel_store.dart';

void main() {
  final store = DemoBookingFunnelStore.instance;

  setUp(store.reset);

  group('ElectronicPaymentCubit (UC-28)', () {
    test(
      'production mode (!isDemoMode) emits pendingIntegration and creates zero transactions',
      () async {
        final cubit = ElectronicPaymentCubit(
          bookingId: 'BK-PROD-1001',
          isDemoMode: false,
          enableTicker: false,
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, ElectronicPaymentStatus.pendingIntegration);
        expect(cubit.state.booking, isNull);
        expect(store.totalBookingsCount, 0);

        cubit.proceedToPayment();
        cubit.simulateVerifiedServerPayment();

        expect(cubit.state.status, ElectronicPaymentStatus.pendingIntegration);
        expect(store.totalBookingsCount, 0);
      },
    );

    test(
      'BR-71, BR-73, PC-06: gateway redirect return (MSG90) does NOT mark booking Confirmed; only verified server IPN (MSG86) confirms booking and issues QR e-ticket (BR-80)',
      () async {
        final fixedNow = DateTime.utc(2026, 10, 7, 10, 0);
        final cubit = ElectronicPaymentCubit(
          bookingId: 'BK-DEMO-1001',
          isDemoMode: true,
          enableTicker: false,
          nowUtcProvider: () => fixedNow,
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, ElectronicPaymentStatus.ready);
        expect(
          cubit.state.booking?.status,
          BookingLifecycleStatus.pendingPayment,
        );
        expect(
          cubit.state.remainingPaymentDuration,
          const Duration(minutes: 15),
        );

        // Select PayOS and initiate payment (BR-71)
        cubit.selectPaymentMethod(PaymentGatewayMethod.payos);
        cubit.proceedToPayment();

        expect(cubit.state.noticeMessage, ElectronicPaymentState.msg85);
        expect(
          cubit.state.booking?.latestTransaction?.method,
          PaymentGatewayMethod.payos,
        );
        expect(
          cubit.state.booking?.latestTransaction?.status,
          PaymentVerificationStatus.redirectingToGateway,
        );

        // Client redirect return BEFORE server IPN -> MSG90, booking MUST remain Pending Payment (BR-73 / PC-06)
        cubit.simulateGatewayReturnNonAuthoritative();
        expect(cubit.state.noticeMessage, ElectronicPaymentState.msg90);
        expect(
          cubit.state.booking?.status,
          BookingLifecycleStatus.pendingPayment,
        );
        expect(cubit.state.booking?.eticket, isNull);

        // Verified server IPN/query -> MSG86, booking becomes Confirmed, QR e-ticket issued (BR-80)
        cubit.simulateVerifiedServerPayment();
        expect(cubit.state.noticeMessage, ElectronicPaymentState.msg86);
        expect(cubit.state.booking?.status, BookingLifecycleStatus.confirmed);
        expect(
          cubit.state.booking?.latestTransaction?.status,
          PaymentVerificationStatus.verifiedSuccess,
        );
        expect(cubit.state.booking?.eticket, isNotNull);
        expect(
          cubit.state.booking?.eticket?.ticketStatus,
          TicketLifecycleStatus.valid,
        );
      },
    );

    test(
      'BR-74: gateway failure/cancel (MSG87) and timeout (MSG89) keep booking Pending Payment while window active',
      () async {
        final cubit = ElectronicPaymentCubit(
          bookingId: 'BK-DEMO-1001',
          isDemoMode: true,
          enableTicker: false,
        );
        addTearDown(cubit.close);

        await cubit.load();

        cubit.simulateGatewayFailedOrCancelled();
        expect(cubit.state.noticeMessage, ElectronicPaymentState.msg87);
        expect(
          cubit.state.booking?.status,
          BookingLifecycleStatus.pendingPayment,
        );
        expect(cubit.state.canProceedToPayment, isTrue);

        cubit.simulateGatewayTimeout();
        expect(cubit.state.noticeMessage, ElectronicPaymentState.msg89);
        expect(
          cubit.state.booking?.status,
          BookingLifecycleStatus.pendingPayment,
        );
        expect(cubit.state.canProceedToPayment, isTrue);
      },
    );

    test(
      'reconciliation mismatch (MSG92) and duplicate/unmatched notification (MSG91) never confirm booking',
      () async {
        final cubit = ElectronicPaymentCubit(
          bookingId: 'BK-DEMO-1001',
          isDemoMode: true,
          enableTicker: false,
        );
        addTearDown(cubit.close);

        await cubit.load();

        cubit.simulateReconciliationMismatch();
        expect(cubit.state.noticeMessage, ElectronicPaymentState.msg92);
        expect(
          cubit.state.booking?.status,
          BookingLifecycleStatus.pendingPayment,
        );

        cubit.simulateDuplicateOrUnmatchedNotification();
        expect(cubit.state.noticeMessage, ElectronicPaymentState.msg91);
        expect(
          cubit.state.booking?.status,
          BookingLifecycleStatus.pendingPayment,
        );
      },
    );

    test(
      'BR-66: payment window expiry (MSG80) and booking cancellation (MSG81) release held slots',
      () async {
        final cubit = ElectronicPaymentCubit(
          bookingId: 'BK-DEMO-1001',
          isDemoMode: true,
          enableTicker: false,
        );
        addTearDown(cubit.close);

        await cubit.load();
        expect(store.heldSlotsForSchedule('sch-001'), 2);

        // Expire 15m window -> MSG80, held slots released
        cubit.simulatePaymentWindowExpired();
        expect(cubit.state.noticeMessage, ElectronicPaymentState.msg80);
        expect(cubit.state.booking?.status, BookingLifecycleStatus.expired);
        expect(store.heldSlotsForSchedule('sch-001'), 0);
        expect(cubit.state.canProceedToPayment, isFalse);

        // Reset and test cancelBooking -> MSG81, held slots released
        store.reset();
        await cubit.load();
        expect(store.heldSlotsForSchedule('sch-001'), 2);

        cubit.cancelBooking();
        expect(cubit.state.noticeMessage, ElectronicPaymentState.msg81);
        expect(cubit.state.booking?.status, BookingLifecycleStatus.cancelled);
        expect(store.heldSlotsForSchedule('sch-001'), 0);
      },
    );

    test(
      'already paid (MSG88), non-owner access (BR-90 / MSG126), and system error (MSG127)',
      () async {
        final cubit = ElectronicPaymentCubit(
          bookingId: 'BK-DEMO-1001',
          isDemoMode: true,
          enableTicker: false,
        );
        addTearDown(cubit.close);

        await cubit.load();

        cubit.simulateAlreadyPaid();
        expect(cubit.state.noticeMessage, ElectronicPaymentState.msg88);
        expect(cubit.state.booking?.status, BookingLifecycleStatus.confirmed);

        cubit.simulateNonOwnerAccess();
        expect(cubit.state.status, ElectronicPaymentStatus.unauthorized);
        expect(cubit.state.noticeMessage, ElectronicPaymentState.msg126);

        cubit.simulateSystemError();
        expect(cubit.state.status, ElectronicPaymentStatus.error);
        expect(cubit.state.errorMessage, ElectronicPaymentState.msg127);
      },
    );
  });
}
