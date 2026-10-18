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
    // UC-28's canonical create response intentionally does not expose an
    // merchant order code. It is a gateway/server reconciliation value.
    orderCode: (json['orderCode'] as num?)?.toInt() ?? 0,
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    currency: json['currency']?.toString() ?? 'VND',
    checkoutUrl: json['checkoutUrl']?.toString() ?? '',
    expiresAt: (json['paymentLinkExpiresAtUtc'] ?? json['expiresAt']) != null
        ? DateTime.tryParse(
                (json['paymentLinkExpiresAtUtc'] ?? json['expiresAt'])
                    .toString(),
              ) ??
              DateTime.now()
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

  // The Backend exposes the latest transaction as top-level canonical fields.
  // Convert it to the display model used by the page; clients never infer a
  // paid state from return parameters or local browser state.
  final topLevelPaymentId = (json['paymentId'] as num?)?.toInt();
  final transactionStatus = json['transactionStatus']?.toString();
  final checkoutUrl = json['checkoutUrl']?.toString() ?? '';
  final topLevelActive =
      topLevelPaymentId != null &&
          transactionStatus != null &&
          checkoutUrl.isNotEmpty
      ? ActivePaymentInfo(
          paymentId: topLevelPaymentId,
          gateway: json['gateway']?.toString() ?? 'PayOS',
          orderCode: 0,
          amount: (json['amount'] as num?)?.toInt() ?? 0,
          currency: json['currency']?.toString() ?? 'VND',
          checkoutUrl: checkoutUrl,
          expiresAt:
              DateTime.tryParse(
                json['paymentLinkExpiresAtUtc']?.toString() ?? '',
              ) ??
              DateTime.now(),
          status: parsePaymentStatus(transactionStatus),
        )
      : null;

  return BookingPaymentStatus(
    bookingId: json['bookingId']?.toString() ?? '',
    bookingCode:
        json['bookingCode']?.toString() ?? '#${json['bookingId'] ?? ''}',
    bookingStatus: json['bookingStatus']?.toString() ?? 'PendingPayment',
    paymentStatus: json['paymentStatus']?.toString() ?? 'Pending',
    paymentExpiresAt:
        (json['bookingPaymentExpiresAtUtc'] ?? json['paymentExpiresAt']) != null
        ? DateTime.tryParse(
                (json['bookingPaymentExpiresAtUtc'] ?? json['paymentExpiresAt'])
                    .toString(),
              ) ??
              DateTime.now()
        : DateTime.now(),
    activePayment: parseActivePayment(activeJson) ?? topLevelActive,
  );
}
