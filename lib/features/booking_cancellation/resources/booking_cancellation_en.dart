/// UC-41 copy. Temporary wording pending Lead/PO sign-off on final MSG codes
/// (mirrors the temporary strings already used on Backend/Web for this task).
abstract final class BookingCancellationStrings {
  static const title = 'Cancel booking';
  static const loading = 'Loading cancellation details…';
  static const refundLabel = 'Estimated refund';
  static const refundPending = 'Refund will be processed (Pending)';
  static const noRefund = 'No refund';
  static const reasonLabel = 'Reason (optional)';
  static const confirmLabel =
      'I confirm I want to cancel this booking and accept the refund amount above.';
  static const confirm = 'Confirm cancellation';
  static const close = 'Close';
  static const cancelled = 'Booking cancelled.';
  static const retry = 'Retry';

  static const signIn = 'Your session has expired. Please sign in again.';
  static const notFound = 'The booking was not found.';
  static const forbidden = 'You do not have permission to cancel this booking.';
  static const invalidState = 'This booking can no longer be cancelled.';
  static const reasonRequired = 'A cancellation reason is required.';
  static const paymentNotRefundable =
      'This booking has no verified payment eligible for a refund.';
  static const windowClosed =
      'This booking cannot be cancelled this close to departure.';
  static const idempotencyMismatch =
      'This cancellation request could not be processed. Please try again.';
  static const system =
      'TripMate is temporarily unable to process your request. Please check your connection and try again.';
}
