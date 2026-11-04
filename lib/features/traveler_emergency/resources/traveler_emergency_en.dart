abstract final class TravelerEmergencyStringsEn {
  static const pageTitle = 'Emergency notice';
  static const stoppedTitle = 'Tour stopped for safety';
  static const cancelledTitle = 'Tour cancelled';
  static const unknownTitle = 'Tour update';
  static const notFoundTitle = 'No emergency notice';
  static const notFoundMessage =
      'There is no emergency notice for this booking on your account.';
  static const loadFailed = 'The emergency notice could not be loaded.';
  static const committedAt = 'Decision time';
  static const instructions = 'Immediate instructions';
  static const contact = 'Emergency contact';
  static const noContact = 'No emergency contact was published.';
  static const call = 'Call operator';
  static const callFailed =
      'Could not start the call. Please dial the contact above.';
  static const reason = 'Reason';
  static const booking = 'Your booking';
  static const bookingStatus = 'Booking status';
  static const scheduleStatus = 'Departure status';
  static const tickets = 'Tickets';
  static const paymentHandlingNotice =
      'Payment and refund handling are managed separately under the applicable booking cancellation policy.';
  static const staleNotice =
      'This notice may be out of date. It will refresh when the connection returns.';
  static const companionReminder =
      'If other people in your group do not have this booking in their app, '
      'please tell them about this notice yourself.';
  static const acknowledgeExplanation =
      'Acknowledging records that you read this notice. It does not mean you are '
      'safe, and it does not change the decision.';
  static const acknowledge = 'I have read this notice';
  static const bannerStopped =
      'A tour you booked was stopped for safety. Tap to read the instructions.';
  static const bannerUpdate =
      'A tour you booked has an important update. Tap to read it.';

  static String bannerSeveral(int count) =>
      'You have $count unread emergency notices. Tap to review your trips.';

  static String acknowledgedAt(String time) => 'Receipt recorded on $time.';

  static String ticketSummary(int total, int cancelled, int used) =>
      '$total total · $cancelled cancelled · $used used';
}
