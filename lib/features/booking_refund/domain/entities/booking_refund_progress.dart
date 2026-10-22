import 'package:equatable/equatable.dart';

enum BookingRefundStatus {
  pending,
  processing,
  retryPending,
  manualReview,
  processed,
  failed,
  rejected;

  static BookingRefundStatus fromWire(String? value) => switch (value) {
    'Processing' => BookingRefundStatus.processing,
    'RetryPending' => BookingRefundStatus.retryPending,
    'ManualReview' => BookingRefundStatus.manualReview,
    'Processed' => BookingRefundStatus.processed,
    'Failed' => BookingRefundStatus.failed,
    'Rejected' => BookingRefundStatus.rejected,
    _ => BookingRefundStatus.pending,
  };
}

final class BookingRefundProgress extends Equatable {
  const BookingRefundProgress({
    required this.bookingId,
    required this.bookingCode,
    required this.refundAmount,
    required this.status,
    required this.attemptCount,
    required this.requestedAtUtc,
    this.gatewayReference,
    this.processedAtUtc,
    this.nextAttemptAtUtc,
  });

  final int bookingId;
  final String bookingCode;
  final int refundAmount;
  final BookingRefundStatus status;
  final int attemptCount;
  final DateTime requestedAtUtc;
  final String? gatewayReference;
  final DateTime? processedAtUtc;
  final DateTime? nextAttemptAtUtc;

  @override
  List<Object?> get props => [
    bookingId,
    bookingCode,
    refundAmount,
    status,
    attemptCount,
    requestedAtUtc,
    gatewayReference,
    processedAtUtc,
    nextAttemptAtUtc,
  ];
}
