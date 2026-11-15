/// English strings for UC-75 (screen #97 Partial Refund Proposal).
///
/// Messages with an SRS catalogue entry use the catalogue wording; message ids are never rendered.
abstract final class PartialRefundProposalStrings {
  // Messages (SRS catalogue wording)

  /// MSG126: the booking of the complaint belongs to another Traveler.
  static const String accessDenied =
      'You do not have permission to access this function.';

  /// MSG127: generic network or server failure.
  static const String systemError =
      'TripMate is temporarily unable to process your request. '
      'Please check your connection and try again.';

  /// MSG164: the response is recorded (shown as a toast).
  static const String recorded = 'Your response has been recorded.';

  /// MSG165: answered already, or the 3-day response window has closed (BR-153).
  static const String responseClosed =
      'The response period has closed. This request can no longer be answered.';

  static const String notFound =
      'This partial refund proposal could not be found.';

  // Screen
  static const String title = 'Partial refund proposal';
  static const String bookingLabel = 'BOOKING';
  static const String proposedAmount = 'Proposed amount';
  static const String responseDeadline = 'Response deadline';
  static const String accept = 'Accept';
  static const String decline = 'Decline';
  static const String cancel = 'Cancel';
  static const String retry = 'Try again';

  // Confirmation (Normal Flow step 3)
  static const String acceptTitle = 'Accept this partial refund?';
  static String acceptMessage(String amount) =>
      'You agree to a refund of $amount for this complaint. '
      'The refund is paid after the Tour Operator confirms it.';
  static const String declineTitle = 'Decline this partial refund?';
  static const String declineMessage =
      'The complaint will then be handled under the partnership contract.';

  // Status
  static const String statusAwaitingTraveler = 'Awaiting your response';
  static const String descriptionAwaitingTraveler =
      'The Tour Operator proposed a partial refund for your complaint. '
      'Accept or decline it before the deadline.';
  static const String statusApproved = 'Accepted';
  static const String descriptionApproved =
      'You accepted the proposed amount. The refund is paid after the '
      'Tour Operator confirms it.';
  static const String statusDeclined = 'Declined';
  static const String descriptionDeclined =
      'The proposal was declined. The complaint is handled under the '
      'partnership contract.';
  static const String statusAwaitingOperator = 'Awaiting Tour Operator';
  static const String descriptionAwaitingOperator =
      'The Tour Operator has not responded to this complaint yet.';
  static const String statusRejected = 'Rejected';
  static const String descriptionRejected =
      'The Tour Operator rejected this complaint. It is handled under the '
      'partnership contract.';
  static const String statusExpired = 'Expired';
  static const String descriptionExpired =
      'The Tour Operator did not respond in time. The complaint is handled '
      'under the partnership contract.';
}
