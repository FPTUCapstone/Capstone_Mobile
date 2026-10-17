abstract final class TourDetailStrings {
  // Navigation & App Bar
  static const String appBarTitle = 'Tour Details';
  static const String backTooltip = 'Back';
  static const String shareTooltip = 'Share tour';

  // Pending Integration View
  static const String pendingIntegrationTitle = 'Connecting Tour Details';
  static const String pendingIntegrationDescription =
      'Tour detail synchronization is awaiting Backend integration. You can review available summary details below or return to tour discovery.';
  static const String backToTourList = 'Back to Tour List';
  static const String summaryNotice =
      'Showing preliminary summary details received from tour search.';

  // Error View
  static const String errorTitle = 'Unable to Load Tour Details';
  static const String retry = 'Retry';

  // Overview Section
  static const String destinationsLabel = 'Destinations';
  static const String operatorLabel = 'Operator';
  static const String contactOperator = 'Contact Operator';
  static String durationDays(int days) => '$days days';

  // Departure Schedules Section
  static const String schedulesTitle = 'Available Departure Dates';
  static const String noSchedules =
      'No departure schedules currently available.';
  static const String soldOut = 'Sold Out';
  static const String capacityUnknown = 'Capacity unknown';
  static const String selected = 'Selected';
  static const String selectDeparture = 'Select';
  static String remainingSlots(int slots) => '$slots slots remaining';

  // Itinerary Section
  static const String itineraryTitle = 'Detailed Itinerary';
  static String dayNumber(int day) => 'Day $day';

  // Services Section
  static const String servicesTitle = 'Services & Amenities';
  static const String inclusionsTitle = 'Inclusions';
  static const String exclusionsTitle = 'Exclusions';

  // Cancellation Policy
  static const String cancellationPolicyTitle = 'Cancellation Policy';

  // Reviews Section
  static const String reviewsTitle = 'Traveler Reviews';
  static const String noReviews =
      'There are no published reviews for this tour yet.';
  static String ratingOutOf5(double rating) => '$rating / 5.0';
  static String reviewCount(int count) => '($count reviews)';

  // Bottom Booking Bar
  static const String fromPrice = 'Price from';
  static const String bookNow = 'Book Now';
  static const String soldOutButton = 'Sold Out';

  // Dialogs
  static const String bookingDialogTitle = 'Book Tour (UC-27)';
  static const String bookingDialogDescription =
      'Tour booking flow (UC-27) is handled in the upcoming booking milestone. Selected schedule:';
  static const String bookingDialogUnderstood = 'Understood';

  static const String loginRequiredTitle = 'Sign In Required';
  static const String loginRequiredDescription =
      'You need to sign in as a Traveler to book this tour.';
  static const String loginLater = 'Maybe Later';
  static const String loginAction = 'Sign In';

  static const String bookingWorkflowTitle = 'Tour Booking Workflow';
  static const String bookingWorkflowDescription =
      'Proceeding to schedule reservation and payment.';
  static const String close = 'Close';

  // Demo Simulation Controls (Debug only)
  static const String demoControlsTitle =
      'DEMO SIMULATION CONTROLS (Debug Mode Only)';
  static const String demoChipAvailable = 'Available';
  static const String demoChipSoldOut = 'Sold Out (MSG65)';
  static const String demoChipNoReviews = 'No Reviews (MSG128)';
  static const String demoChipError = 'Error (MSG127)';
}
