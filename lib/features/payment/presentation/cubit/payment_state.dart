import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/payment/domain/entities/payment_link.dart';

enum PaymentActionStatus {
  idle,
  loading,
  linkCreated,
  statusLoaded,
  outcomeCompleted,
  failure,
}

final class PaymentState extends Equatable {
  const PaymentState({
    this.status = PaymentActionStatus.idle,
    this.paymentLink,
    this.paymentStatus,
    this.failure,
  });

  final PaymentActionStatus status;
  final PaymentLink? paymentLink;
  final BookingPaymentStatus? paymentStatus;
  final Failure? failure;

  bool get isLoading => status == PaymentActionStatus.loading;

  PaymentState copyWith({
    PaymentActionStatus? status,
    PaymentLink? paymentLink,
    BookingPaymentStatus? paymentStatus,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return PaymentState(
      status: status ?? this.status,
      paymentLink: paymentLink ?? this.paymentLink,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, paymentLink, paymentStatus, failure];
}
