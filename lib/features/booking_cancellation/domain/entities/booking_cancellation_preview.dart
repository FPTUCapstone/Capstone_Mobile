import 'package:equatable/equatable.dart';

/// UC-41 preview shown before the Traveler confirms a cancellation
/// (`GET /api/v1/bookings/{bookingId}/cancellation-preview`).
final class BookingCancellationPreview extends Equatable {
  const BookingCancellationPreview({
    required this.bookingId,
    required this.tourTitle,
    required this.bookingStatus,
    required this.paymentStatus,
    required this.totalAmount,
    required this.canCancel,
    required this.estimatedRefundAmount,
    required this.refundStatus,
    this.blockingReasonCode,
    this.blockingReason,
  });

  final int bookingId;
  final String tourTitle;
  final String bookingStatus;
  final String paymentStatus;
  final double totalAmount;
  final bool canCancel;

  /// Present (even when [canCancel] is true) for `booking.cancellation.confirmation_required`:
  /// a 0% refund that still requires the Traveler to tick a confirmation before submitting.
  final String? blockingReasonCode;
  final String? blockingReason;
  final double estimatedRefundAmount;
  final String refundStatus;

  @override
  List<Object?> get props => [
    bookingId,
    tourTitle,
    bookingStatus,
    paymentStatus,
    totalAmount,
    canCancel,
    blockingReasonCode,
    blockingReason,
    estimatedRefundAmount,
    refundStatus,
  ];
}
