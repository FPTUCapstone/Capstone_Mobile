import 'package:equatable/equatable.dart';

enum PaymentTransactionStatus { pending, success, cancelled, expired, failed }

final class PaymentLink extends Equatable {
  const PaymentLink({
    required this.paymentId,
    required this.bookingId,
    required this.orderCode,
    required this.amount,
    required this.currency,
    required this.checkoutUrl,
    required this.expiresAt,
    required this.status,
  });

  final int paymentId;
  final String bookingId;
  final int orderCode;
  final int amount;
  final String currency;
  final String checkoutUrl;
  final DateTime expiresAt;
  final PaymentTransactionStatus status;

  @override
  List<Object?> get props => [
    paymentId,
    bookingId,
    orderCode,
    amount,
    currency,
    checkoutUrl,
    expiresAt,
    status,
  ];
}

final class ActivePaymentInfo extends Equatable {
  const ActivePaymentInfo({
    required this.paymentId,
    required this.gateway,
    required this.orderCode,
    required this.amount,
    required this.currency,
    required this.checkoutUrl,
    required this.expiresAt,
    required this.status,
  });

  final int paymentId;
  final String gateway;
  final int orderCode;
  final int amount;
  final String currency;
  final String checkoutUrl;
  final DateTime expiresAt;
  final PaymentTransactionStatus status;

  @override
  List<Object?> get props => [
    paymentId,
    gateway,
    orderCode,
    amount,
    currency,
    checkoutUrl,
    expiresAt,
    status,
  ];
}

final class BookingPaymentStatus extends Equatable {
  const BookingPaymentStatus({
    required this.bookingId,
    required this.bookingCode,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.paymentExpiresAt,
    this.activePayment,
  });

  final String bookingId;
  final String bookingCode;
  final String bookingStatus;
  final String paymentStatus;
  final DateTime paymentExpiresAt;
  final ActivePaymentInfo? activePayment;

  bool get isPaid => bookingStatus == 'Confirmed' || paymentStatus == 'Paid';
  bool get isExpired => bookingStatus == 'Expired';
  bool get isPending => bookingStatus == 'PendingPayment';
  bool get isCancelledTx =>
      activePayment?.status == PaymentTransactionStatus.cancelled;

  @override
  List<Object?> get props => [
    bookingId,
    bookingCode,
    bookingStatus,
    paymentStatus,
    paymentExpiresAt,
    activePayment,
  ];
}
