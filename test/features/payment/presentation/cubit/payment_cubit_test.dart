import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/complete_mock_payment_use_case.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/create_or_reuse_payment_use_case.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/get_booking_payment_status_use_case.dart';
import 'package:trip_mate_mobile/features/payment/presentation/cubit/payment_cubit.dart';
import 'package:trip_mate_mobile/features/payment/presentation/cubit/payment_state.dart';

import '../../payment_fakes.dart';

void main() {
  group('PaymentCubit', () {
    late FakePaymentRepository repository;
    late PaymentCubit cubit;

    setUp(() {
      repository = FakePaymentRepository();
      cubit = PaymentCubit(
        createOrReusePayment: CreateOrReusePaymentUseCase(repository),
        getBookingPaymentStatus: GetBookingPaymentStatusUseCase(repository),
        completeMockPayment: CompleteMockPaymentUseCase(repository),
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state is idle with no data', () {
      expect(cubit.state.status, PaymentActionStatus.idle);
      expect(cubit.state.paymentLink, isNull);
      expect(cubit.state.paymentStatus, isNull);
      expect(cubit.state.failure, isNull);
    });

    test('startPayment successfully creates link and loads status', () async {
      await cubit.startPayment('booking-123');

      expect(repository.createCalls, 1);
      expect(repository.statusCalls, 1);
      expect(cubit.state.status, PaymentActionStatus.linkCreated);
      expect(cubit.state.paymentLink?.paymentId, 101);
      expect(cubit.state.paymentStatus?.bookingCode, 'BK-TEST');
      expect(cubit.state.failure, isNull);
    });

    test('startPayment emits failure when createOrReusePayment fails', () async {
      repository.failCreate = true;

      await cubit.startPayment('booking-123');

      expect(repository.createCalls, 1);
      expect(cubit.state.status, PaymentActionStatus.failure);
      expect(cubit.state.failure?.message, 'Payment link creation failed');
    });

    test('refreshStatus updates paymentStatus', () async {
      await cubit.refreshStatus('booking-123');

      expect(repository.statusCalls, 1);
      expect(cubit.state.status, PaymentActionStatus.statusLoaded);
      expect(cubit.state.paymentStatus?.bookingId, 'booking-123');
    });

    test('refreshStatus emits failure when remote status fails', () async {
      repository.failStatus = true;

      await cubit.refreshStatus('booking-123');

      expect(repository.statusCalls, 1);
      expect(cubit.state.status, PaymentActionStatus.failure);
      expect(cubit.state.failure?.message, 'Status retrieval failed');
    });

    test('submitMockOutcome Success transitions booking to confirmed', () async {
      await cubit.startPayment('booking-123');
      expect(cubit.state.paymentStatus?.isPaid, isFalse);

      await cubit.submitMockOutcome(
        paymentId: 101,
        bookingId: 'booking-123',
        outcome: 'Success',
      );

      expect(repository.mockCalls, 1);
      expect(cubit.state.status, PaymentActionStatus.outcomeCompleted);
      expect(cubit.state.paymentStatus?.isPaid, isTrue);
      expect(cubit.state.paymentStatus?.bookingStatus, 'Confirmed');
    });

    test('submitMockOutcome Expired transitions booking to expired', () async {
      await cubit.submitMockOutcome(
        paymentId: 101,
        bookingId: 'booking-123',
        outcome: 'Expired',
      );

      expect(repository.mockCalls, 1);
      expect(cubit.state.status, PaymentActionStatus.outcomeCompleted);
      expect(cubit.state.paymentStatus?.isExpired, isTrue);
    });

    test('submitMockOutcome handles failure gracefully', () async {
      repository.failMock = true;

      await cubit.submitMockOutcome(
        paymentId: 101,
        bookingId: 'booking-123',
        outcome: 'Success',
      );

      expect(repository.mockCalls, 1);
      expect(cubit.state.status, PaymentActionStatus.failure);
      expect(cubit.state.failure?.message, 'Mock completion failed');
    });
  });
}
