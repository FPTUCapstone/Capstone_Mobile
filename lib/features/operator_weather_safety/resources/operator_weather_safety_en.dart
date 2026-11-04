import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/emergency_decision_state.dart';

abstract final class OperatorWeatherSafetyStringsEn {
  static const safetyAlerts = 'Safety Alerts';
  static const filterAll = 'All';
  static const emptyTitle = 'No safety alerts';
  static const emptyMessage =
      'Weather safety reviews for your tours appear here.';
  static const staleList =
      'This list may be out of date. It will refresh when you are back online.';
  static const loadFailed = 'Safety alerts could not be loaded.';
  static const notProvided = 'Not provided';
  static const staleReview =
      'This alert may be out of date. It will refresh when the connection returns.';

  static String reviewStatus(WeatherSafetyReviewStatus status) =>
      switch (status) {
        WeatherSafetyReviewStatus.pendingAcknowledgement =>
          'Pending acknowledgement',
        WeatherSafetyReviewStatus.escalated => 'Escalated',
        WeatherSafetyReviewStatus.acknowledged => 'Acknowledged',
        WeatherSafetyReviewStatus.closed => 'Closed',
        WeatherSafetyReviewStatus.unknown => 'Unknown status',
      };

  static String badgeSemantics(int count) =>
      '$safetyAlerts, $count need attention';

  // Review detail
  static const reviewTitle = 'Safety alert';
  static const reviewNotFound = 'Safety alert not found';
  static const reviewNotFoundMessage =
      'This alert is not available on your account.';
  static const sectionWeather = 'Weather event';
  static const sectionDeparture = 'Departure';
  static const sectionResponse = 'Response';
  static const eventType = 'Event';
  static const severity = 'Severity';
  static const description = 'Description';
  static const authority = 'Authority';
  static const riskLevel = 'Official risk level';
  static const directive = 'Directive';
  static const affectedArea = 'Affected area';
  static const validFrom = 'Effective from';
  static const validTo = 'Effective until';
  static const withdrawn = 'This weather event has been withdrawn.';
  static const scheduleStart = 'Starts';
  static const scheduleEnd = 'Ends';
  static const scheduleStatus = 'Departure status';
  static const noticeSent = 'Notice sent';
  static const deadline = 'Acknowledge by';
  static const acknowledgedAt = 'Acknowledged';
  static const escalatedAt = 'Escalated';
  static const escalationContact = 'Escalation contact';
  static const instructions = 'Immediate instructions';
  static const instructionsOptional = 'Immediate instructions (optional)';
  static const acknowledge = 'Acknowledge alert';
  static const acknowledgeExplanation =
      'Acknowledging confirms you saw this alert. It does not change the tour, '
      'bookings or trips.';
  static const reviewDecision = 'Review emergency options';
  static const manageEvidence = 'Manage emergency evidence';

  // Decision
  static const decisionTitle = 'Emergency decision';
  static const departureNotFound = 'Departure not found';
  static const departureNotFoundMessage =
      'This departure is not available on your account.';
  static const cancelAction = 'Cancel before departure';
  static const stopAction = 'Emergency stop';
  static const impactTitle = 'Latest impact';
  static const paidBookings = 'Paid bookings';
  static const unpaidBookings = 'Unpaid bookings';
  static const passengers = 'Affected passengers';
  static const activeSessions = 'Active trip sessions';
  static const unusedTickets = 'Unused tickets';
  static const paymentHandlingNotice =
      'Payment and refund handling are managed separately under the applicable booking cancellation policy.';
  static const impactChanged =
      'The impact changed. Please review the latest impact before confirming.';
  static const checkAgain = 'Check again';

  static String blockMessage(EmergencyBlockReason reason) => switch (reason) {
    EmergencyBlockReason.offline =>
      'You are offline. Emergency actions are unavailable until you reconnect.',
    EmergencyBlockReason.unverifiedSessions =>
      'Some trip sessions could not be verified, so emergency actions are unavailable.',
    EmergencyBlockReason.unsupportedAction =>
      'This version of the app cannot perform the action required for this departure.',
    EmergencyBlockReason.terminal =>
      'This departure already has a final decision.',
    EmergencyBlockReason.completed =>
      'This departure is completed and cannot be cancelled or stopped.',
    EmergencyBlockReason.forbidden =>
      'Your account cannot perform emergency actions on this departure.',
    EmergencyBlockReason.unavailable =>
      'The latest impact could not be loaded, so emergency actions are unavailable.',
  };

  // Form
  static const reason = 'Reason';
  static const reasonDetails = 'Reason details';
  static const reasonRequired = 'Describe the reason.';
  static const instructionsRequired = 'Enter safety instructions.';
  static const contact = 'Emergency contact';
  static const contactOptional = 'Emergency contact (optional)';
  static const contactRequired = 'Enter an emergency contact.';
  static const evidenceTitle = 'Evidence (optional)';
  static const evidenceUrl = 'Evidence link';
  static const evidenceUrlHint = 'https://';
  static const evidenceUrlInvalid =
      'Enter an HTTPS link without a username or password.';
  static const authorityReference = 'Authority reference';
  static const evidenceReference = 'Evidence reference';
  static const addLater = 'Add evidence later';
  static const authorityEvidenceRequired =
      'Add an authority reference or evidence reference, or choose to add evidence later.';
  static const password = 'Current password';
  static const passwordRequired = 'Enter your current password.';
  static const reviewAndConfirm = 'Review and confirm';

  // Confirmation
  static const keepTour = 'Go back';
  static const confirmCancelTitle = 'Cancel this departure?';
  static const confirmStopTitle = 'Stop this tour now?';
  static const confirmCancelSubmit = 'Cancel departure';
  static const confirmStopSubmit = 'Stop tour';
  static const confirmIrreversible =
      'This decision is final and notifies affected Travelers.';

  static String confirmImpact(int passengers, int paid, int unpaid) =>
      'Affects $passengers passengers across $paid paid and $unpaid unpaid bookings.';

  // Outcome
  static const ambiguous =
      'We could not confirm whether your decision was saved. Retry sends the '
      'exact same request and cannot create a second decision.';
  static const retrySubmit = 'Retry the same request';
  static const checkStatus = 'Check status instead';
  static const successCancelled = 'Departure cancelled';
  static const successStopped = 'Tour stopped';

  static String successMessage(int bookings) =>
      '$bookings bookings were affected. Travelers can read the decision in the app.';

  // Evidence editor
  static const manageEvidenceTitle = 'Emergency evidence';
  static const evidenceEmpty = 'Add a link or a reference.';
  static const evidenceClears =
      'Saved values are shown below. Saving keeps what you leave here and clears a field you empty.';
  static const evidenceSave = 'Save evidence';
  static const evidenceWithdraw = 'Withdraw evidence';
  static const evidenceWithdrawConfirm = 'Withdraw';
  static const evidenceWithdrawTitle = 'Withdraw the evidence?';
  static const evidenceWithdrawMessage =
      'The saved link and references are removed from this decision.';
  static const evidenceSaved = 'Evidence saved.';
  static const evidenceWithdrawn = 'Evidence withdrawn.';
}
