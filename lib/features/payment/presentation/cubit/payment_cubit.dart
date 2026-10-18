import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/complete_mock_payment_use_case.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/create_or_reuse_payment_use_case.dart';
import 'package:trip_mate_mobile/features/payment/domain/usecases/get_booking_payment_status_use_case.dart';
import 'package:trip_mate_mobile/features/payment/presentation/cubit/payment_state.dart';

final class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit({
    required CreateOrReusePaymentUseCase createOrReusePayment,
    required GetBookingPaymentStatusUseCase getBookingPaymentStatus,
    required CompleteMockPaymentUseCase completeMockPayment,
  }) : _createOrReusePayment = createOrReusePayment,
       _getBookingPaymentStatus = getBookingPaymentStatus,
       _completeMockPayment = completeMockPayment,
       super(const PaymentState());

  final CreateOrReusePaymentUseCase _createOrReusePayment;
  final GetBookingPaymentStatusUseCase _getBookingPaymentStatus;
  final CompleteMockPaymentUseCase _completeMockPayment;

  Future<void> startPayment(String bookingId) async {
    emit(
      state.copyWith(status: PaymentActionStatus.loading, clearFailure: true),
    );
    try {
      final link = await _createOrReusePayment(bookingId);
      final status = await _getBookingPaymentStatus(bookingId);
      emit(
        state.copyWith(
          status: PaymentActionStatus.linkCreated,
          paymentLink: link,
          paymentStatus: status,
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(status: PaymentActionStatus.failure, failure: failure),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PaymentActionStatus.failure,
          failure: const ServerFailure('Could not connect to payment gateway.'),
        ),
      );
    }
  }

  Future<void> refreshStatus(String bookingId) async {
    emit(
      state.copyWith(status: PaymentActionStatus.loading, clearFailure: true),
    );
    try {
      final status = await _getBookingPaymentStatus(bookingId);
      emit(
        state.copyWith(
          status: PaymentActionStatus.statusLoaded,
          paymentStatus: status,
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(status: PaymentActionStatus.failure, failure: failure),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PaymentActionStatus.failure,
          failure: const ServerFailure('Could not refresh payment status.'),
        ),
      );
    }
  }

  Future<void> submitMockOutcome({
    required int paymentId,
    required String bookingId,
    required String outcome,
  }) async {
    emit(
      state.copyWith(status: PaymentActionStatus.loading, clearFailure: true),
    );
    try {
      await _completeMockPayment(paymentId: paymentId, outcome: outcome);
      final status = await _getBookingPaymentStatus(bookingId);
      emit(
        state.copyWith(
          status: PaymentActionStatus.outcomeCompleted,
          paymentStatus: status,
        ),
      );
    } on Failure catch (failure) {
      emit(
        state.copyWith(status: PaymentActionStatus.failure, failure: failure),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: PaymentActionStatus.failure,
          failure: const ServerFailure('Could not complete mock transaction.'),
        ),
      );
    }
  }
}
