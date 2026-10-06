import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/booking_participant.dart';
import 'package:trip_mate_mobile/features/tour_booking/domain/entities/tour_booking_record.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/tour_booking_cubit.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/cubit/tour_booking_state.dart';
import 'package:trip_mate_mobile/features/tour_booking/presentation/demo/demo_booking_funnel_store.dart';

void main() {
  final store = DemoBookingFunnelStore.instance;

  setUp(store.reset);

  group('TourBookingCubit (UC-27)', () {
    test(
      'production mode (!isDemoMode) emits pendingIntegration and creates zero bookings',
      () async {
        final cubit = TourBookingCubit(
          tourId: 'tour-prod-1',
          isDemoMode: false,
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, TourBookingStatus.pendingIntegration);
        expect(store.totalBookingsCount, 0);

        // Attempting mutations in production mode does nothing
        cubit.setVoucherInput('SUMMER2026');
        cubit.applyVoucher();
        await cubit.confirmBooking();

        expect(cubit.state.status, TourBookingStatus.pendingIntegration);
        expect(cubit.state.createdBooking, isNull);
        expect(store.totalBookingsCount, 0);
      },
    );

    test(
      'demo mode loads selected schedule and calculates unit price and remaining slots',
      () async {
        final cubit = TourBookingCubit(
          tourId: 'demo-tour-1',
          initialScheduleId: 'sch-002',
          isDemoMode: true,
        );
        addTearDown(cubit.close);

        await cubit.load();

        expect(cubit.state.status, TourBookingStatus.ready);
        expect(cubit.state.selectedSchedule?.scheduleId, 'sch-002');
        expect(cubit.state.effectiveRemainingSlots, 3);
        expect(cubit.state.unitPrice, 2890000);
        expect(cubit.state.participantCount, 1);
        expect(cubit.state.subtotal, 2890000);
        expect(cubit.state.totalAmount, 2890000);
      },
    );

    test(
      'setParticipantCount resizes participant cards and surfaces MSG77 when exceeding remaining slots',
      () async {
        final cubit = TourBookingCubit(
          tourId: 'demo-tour-1',
          initialScheduleId: 'sch-002', // 3 slots
          isDemoMode: true,
        );
        addTearDown(cubit.close);

        await cubit.load();

        cubit.setParticipantCount(2);
        expect(cubit.state.participantCount, 2);
        expect(cubit.state.participants.length, 2);
        expect(cubit.state.subtotal, 5780000);
        expect(cubit.state.validationMessage, isNull);

        // Requesting 4 participants when only 3 remain -> MSG77
        cubit.setParticipantCount(4);
        expect(cubit.state.participantCount, 2);
        expect(cubit.state.validationMessage, TourBookingState.msg77);
      },
    );

    test(
      'validateBeforeConfirmation enforces MSG01 on empty required fields and MSG78 on invalid format',
      () async {
        final cubit = TourBookingCubit(tourId: 'demo-tour-1', isDemoMode: true);
        addTearDown(cubit.close);

        await cubit.load();

        // Empty fullName -> MSG01
        cubit.updateParticipant(
          0,
          const BookingParticipant(
            fullName: '   ',
            dateOfBirth: '15/05/1996',
            identityDocumentNumber: '048096001234',
            phoneNumber: '0905123456',
          ),
        );
        expect(cubit.validateBeforeConfirmation(), isFalse);
        expect(cubit.state.validationMessage, TourBookingState.msg01);

        // Non-empty but invalid identity document -> MSG78
        cubit.updateParticipant(
          0,
          const BookingParticipant(
            fullName: 'Nguyễn Minh Quân',
            dateOfBirth: '15/05/1996',
            identityDocumentNumber: '123', // too short
            phoneNumber: '0905123456',
          ),
        );
        expect(cubit.validateBeforeConfirmation(), isFalse);
        expect(cubit.state.validationMessage, TourBookingState.msg78);
      },
    );

    test(
      'voucher evaluation covers MSG100 (applied), MSG101 (invalid/expired), MSG102 (min spend), MSG103 (removed), and BR-100 (non-negative total)',
      () async {
        final cubit = TourBookingCubit(tourId: 'demo-tour-1', isDemoMode: true);
        addTearDown(cubit.close);

        await cubit.load();

        // Valid voucher SUMMER2026 (-200,000 VND) -> MSG100
        cubit.setVoucherInput('summer2026');
        cubit.applyVoucher();
        expect(cubit.state.appliedVoucherCode, 'SUMMER2026');
        expect(cubit.state.discountAmount, 200000);
        expect(cubit.state.totalAmount, 2890000 - 200000);
        expect(cubit.state.voucherNotice, TourBookingState.msg100);
        expect(cubit.state.isVoucherError, isFalse);

        // Remove voucher -> MSG103
        cubit.removeVoucher();
        expect(cubit.state.appliedVoucherCode, isNull);
        expect(cubit.state.discountAmount, 0);
        expect(cubit.state.totalAmount, 2890000);
        expect(cubit.state.voucherNotice, TourBookingState.msg103);

        // Minimum spend not met (VIP500 requires 15,000,000 VND) -> MSG102
        cubit.setVoucherInput('VIP500');
        cubit.applyVoucher();
        expect(cubit.state.appliedVoucherCode, isNull);
        expect(cubit.state.discountAmount, 0);
        expect(cubit.state.voucherNotice, TourBookingState.msg102);
        expect(cubit.state.isVoucherError, isTrue);

        // Expired / invalid voucher -> MSG101
        cubit.setVoucherInput('EXPIRED2025');
        cubit.applyVoucher();
        expect(cubit.state.appliedVoucherCode, isNull);
        expect(cubit.state.voucherNotice, TourBookingState.msg101);
        expect(cubit.state.isVoucherError, isTrue);

        // BR-100: BIGSAVE (5,000,000 VND discount) is clamped to subtotal (2,890,000 VND) so total is 0, never negative
        cubit.setVoucherInput('BIGSAVE');
        cubit.applyVoucher();
        expect(cubit.state.appliedVoucherCode, 'BIGSAVE');
        expect(cubit.state.clampedDiscount, 2890000);
        expect(cubit.state.totalAmount, 0);
      },
    );

    test(
      'confirmBooking creates Pending Payment booking with 15-minute expiry, holds slots (BR-66), and emits MSG79',
      () async {
        final cubit = TourBookingCubit(
          tourId: 'demo-tour-1',
          initialScheduleId: 'sch-001', // 8 slots
          isDemoMode: true,
        );
        addTearDown(cubit.close);

        await cubit.load();
        cubit.setParticipantCount(2);
        cubit.setVoucherInput('SUMMER2026');
        cubit.applyVoucher();

        await cubit.confirmBooking();

        expect(cubit.state.status, TourBookingStatus.bookingCreated);
        expect(cubit.state.statusMessage, TourBookingState.msg79);
        final booking = cubit.state.createdBooking;
        expect(booking, isNotNull);
        expect(booking!.status, BookingLifecycleStatus.pendingPayment);
        expect(booking.participantCount, 2);
        expect(booking.subtotal, 5780000);
        expect(booking.discountAmount, 200000);
        expect(booking.totalAmount, 5580000);
        expect(
          booking.paymentExpiresAtUtc.difference(booking.createdAtUtc),
          const Duration(minutes: 15),
        );
        expect(store.heldSlotsForSchedule('sch-001'), 2);
        expect(cubit.state.effectiveRemainingSlots, 6);
      },
    );

    test(
      'demo simulations cover MSG65 (sold out), MSG77 (revalidation insufficient slots), MSG126 (max unpaid bookings), and MSG127 (error)',
      () async {
        final cubit = TourBookingCubit(tourId: 'demo-tour-1', isDemoMode: true);
        addTearDown(cubit.close);

        await cubit.load();

        cubit.simulateScheduleSoldOut();
        expect(cubit.state.validationMessage, TourBookingState.msg65);
        expect(cubit.validateBeforeConfirmation(), isFalse);

        cubit.resetDemoSimulations();
        cubit.simulateInsufficientSlotsAtRevalidation();
        await cubit.confirmBooking();
        expect(cubit.state.validationMessage, TourBookingState.msg77);

        cubit.resetDemoSimulations();
        cubit.simulateMaxUnpaidBookingsReached();
        expect(cubit.validateBeforeConfirmation(), isFalse);
        expect(cubit.state.validationMessage, TourBookingState.msg126);

        cubit.simulateError();
        expect(cubit.state.status, TourBookingStatus.error);
        expect(cubit.state.errorMessage, TourBookingState.msg127);
      },
    );
  });
}
