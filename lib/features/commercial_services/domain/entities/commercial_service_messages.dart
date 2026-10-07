/// Canonical application messages for UC-30 (View Commercial Service) and
/// UC-31 (Book Commercial Service) aligned with Report 3 SRS Sections 3.6.1
/// and 3.6.2.
abstract final class CommercialServiceMessages {
  /// `MSG01`: A required booking field is empty.
  static const String msg01 = 'This field is required. (MSG01)';

  /// `MSG34`: The point of interest is not Active or no longer exists (`BR-34`).
  static const String msg34 =
      'This point of interest is no longer active or does not exist. (MSG34)';

  /// `MSG69`: The commercial service booking request is created with status
  /// `Pending Confirmation` (`BR-89`).
  static const String msg69 =
      'Your booking request has been created with status Pending Confirmation and transmitted to the commercial service provider. (MSG69)';

  /// `MSG70`: The requested date or the requested time is not available (`BR-88`).
  static const String msg70 =
      'The requested date or requested time is not available for this service. (MSG70)';

  /// `MSG71`: The requested quantity exceeds the available quantity (`BR-88`).
  static const String msg71 =
      'The requested quantity exceeds the available quantity for this service. (MSG71)';

  /// `MSG72`: The commercial service provider confirms the request (`BR-89`).
  static const String msg72 =
      'The commercial service provider has confirmed your booking request. The confirmed service is now reflected in your associated itinerary. (MSG72)';

  /// `MSG73`: The commercial service provider rejects the request (`BR-89`).
  static const String msg73 =
      'The commercial service provider has rejected your booking request. No service has been reserved. (MSG73)';

  /// `MSG74`: The Traveler cancels a `Pending Confirmation` request (`BR-76`).
  static const String msg74 =
      'Your booking request has been cancelled. Where a payment has been collected, the refund is returned through the original payment channel. (MSG74)';

  /// `MSG75`: The service is not currently open for booking (`BR-88`).
  static const String msg75 =
      'This commercial service is not currently open for booking. (MSG75)';

  /// `MSG76`: The requested date is in the past.
  static const String msg76 =
      'The requested date cannot be in the past. (MSG76)';

  /// `MSG126`: Role/permission denial.
  static const String msg126 =
      'You do not have permission to access this function. (MSG126)';

  /// `MSG127`: Generic system or network failure.
  static const String msg127 =
      'TripMate is temporarily unable to process your request. Please check your connection and try again. (MSG127)';
}
