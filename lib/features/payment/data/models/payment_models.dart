import 'package:trip_mate_mobile/features/payment/domain/entities/payment_link.dart';

PaymentTransactionStatus parsePaymentStatus(String? value) {
  switch (value?.toLowerCase()) {
    case 'success':
      return PaymentTransactionStatus.success;
    case 'cancelled':
      return PaymentTransactionStatus.cancelled;
    case 'expired':
      return PaymentTransactionStatus.expired;
    case 'failed':
      return PaymentTransactionStatus.failed;
    case 'pending':
    default:
      return PaymentTransactionStatus.pending;
  }
}

PaymentLink parsePaymentLink(Map<String, dynamic> json) {
  return PaymentLink(
    paymentId: (json['paymentId'] as num?)?.toInt() ?? 0,
    bookingId: json['bookingId']?.toString() ?? '',
    orderCode: (json['orderCode'] as num?)?.toInt() ?? 0,
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    currency: json['currency']?.toString() ?? 'VND',
    checkoutUrl: json['checkoutUrl']?.toString() ?? '',
    expiresAt: json['expiresAt'] != null
        ? DateTime.tryParse(json['expiresAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    status: parsePaymentStatus(json['status']?.toString()),
  );
}

ActivePaymentInfo? parseActivePayment(Map<String, dynamic>? json) {
  if (json == null) return null;
  return ActivePaymentInfo(
    paymentId: (json['paymentId'] as num?)?.toInt() ?? 0,
    gateway: json['gateway']?.toString() ?? 'PayOS',
    orderCode: (json['orderCode'] as num?)?.toInt() ?? 0,
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    currency: json['currency']?.toString() ?? 'VND',
    checkoutUrl: json['checkoutUrl']?.toString() ?? '',
    expiresAt: json['expiresAt'] != null
        ? DateTime.tryParse(json['expiresAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    status: parsePaymentStatus(json['status']?.toString()),
  );
}

BookingPaymentStatus parseBookingPaymentStatus(Map<String, dynamic> json) {
  final activeJson = json['activePayment'] is Map<String, dynamic>
      ? json['activePayment'] as Map<String, dynamic>
      : null;

  return BookingPaymentStatus(
    bookingId: json['bookingId']?.toString() ?? '',
    bookingCode: json['bookingCode']?.toString() ?? '',
    bookingStatus: json['bookingStatus']?.toString() ?? 'PendingPayment',
    paymentStatus: json['paymentStatus']?.toString() ?? 'Pending',
    paymentExpiresAt: json['paymentExpiresAt'] != null
        ? DateTime.tryParse(json['paymentExpiresAt'].toString()) ??
            DateTime.now()
        : DateTime.now(),
    activePayment: parseActivePayment(activeJson),
  );
}
