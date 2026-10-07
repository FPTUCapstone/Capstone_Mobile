/// English resource strings for UC-30 and UC-31 commercial service features,
/// satisfying Report 3 V2 CR-09 (English UI language and centralized resources).
///
/// Notice: Conflicted numeric rule identifiers (e.g., BR-34, BR-63, BR-76, BR-89)
/// and numeric message codes (e.g., MSG69, MSG70) are intentionally omitted from
/// user-facing copy per SRS_INTERNAL_CONFLICT_COMMERCIAL_BR_IDS and
/// SRS_INTERNAL_CONFLICT_COMMERCIAL_MESSAGE_IDS.
abstract final class CommercialServiceEn {
  static const search = _SearchStrings();
  static const detail = _DetailStrings();
  static const booking = _BookingStrings();
  static const messages = _MessageStrings();
  static const demo = _DemoStrings();
  static const a11y = _AccessibilityStrings();
}

final class _SearchStrings {
  const _SearchStrings();

  final String title = 'Commercial Services';
  final String searchHint = 'Search hotels, rentals, restaurants...';
  final String categoryAll = 'All';
  final String categoryHotel = 'Hotel';
  final String categoryVehicle = 'Vehicle Rental';
  final String categoryRestaurant = 'Restaurant';
  final String productionNotice =
      'Live catalog from Backend (GET /api/v1/pois). Category, date availability, and price filters are Pending Server Integration.';
  final String demoNotice =
      'Demo Mode active: Multi-criteria filtering (category, date, price) enabled with deterministic fixtures.';
  final String categoryPendingTooltip =
      'Category filtering is pending server integration in Production.';
  final String emptyMessage =
      'No commercial services found matching your criteria.';
  final String resetFilters = 'Reset filters';
  final String retry = 'Retry';
  final String loading = 'Loading commercial services...';
  final String pendingServerIntegration = 'Pending Server Integration';
  final String fromPrice = 'From';
  final String available = 'Available';
  final String fullyBooked = 'Fully Booked';
  final String availabilityMissing = 'Availability Missing';
  final String viewDetails = 'View Commercial Details';
}

final class _DetailStrings {
  const _DetailStrings();

  final String title = 'Commercial Service Details';
  final String overview = 'Overview';
  final String options = 'Service Options';
  final String contact = 'Contact & Location';
  final String availabilityTitle = 'Display-Time Availability';
  final String intendedDatePrefix = 'Intended Service Date:';
  final String bookService = 'Book Service';
  final String closedForBooking =
      'This service is currently closed for booking.';
  final String availabilityUnavailableNotice =
      'Availability information is currently unavailable for this date. Booking is disabled until availability can be verified.';
  final String nonCommercialNotice =
      'This point of interest is not registered as a commercial service provider. Direct booking is not available.';
  final String inactivePoiNotice =
      'This service is currently inactive and cannot be viewed.';
  final String productionPendingNotice =
      'This commercial service detail is loaded from the POI catalog. Booking mutation and live availability are pending server integration.';
  final String availabilityNotice =
      'Retrieved at display time only. This indicator is not a reservation or slot hold.';
  final String bookServiceRequiresAvailability =
      'Book Service requires verified display-time availability for the selected date.';
  final String commercialServiceBadge = 'Commercial Service';
  final String availableUnitsSuffix = 'available';
  final String locationMapProjection = 'Location Map Projection';
}

final class _BookingStrings {
  const _BookingStrings();

  final String title = 'Commercial Service Booking';
  final String bookingDetails = 'Booking Details';
  final String selectedOptionLabel = 'Selected Service Option *';
  final String requestedDateLabel = 'Requested Date (YYYY-MM-DD) *';
  final String requestedTimeLabel = 'Requested Time (HH:mm) *';
  final String availableUnitsPrefix = 'Available:';
  final String quantityLabel = 'Quantity *';
  final String specialRequestsLabel = 'Special Requests (Optional)';
  final String specialRequestsHint =
      'e.g., quiet room, high floor, child seat...';
  final String contactInformation = 'Contact Information';
  final String contactNameLabel = 'Contact Full Name *';
  final String contactPhoneLabel = 'Contact Phone Number *';
  final String contactEmailLabel = 'Contact Email *';
  final String estimatedAmountTitle = 'Estimated Amount';
  final String estimatedAmountPending =
      'Estimated amount will be calculated by the server when booking integration is available.';
  final String demoPreviewAmountTitle = 'Demo Preview Amount';
  final String demoPreviewAmountCaption =
      'Server computes authoritative amount in Production.';
  final String submitButton = 'Submit Booking Request';
  final String confirmDialogTitle = 'Confirm Booking Request';
  final String confirmDialogBody =
      'Are you sure you want to submit this commercial service booking request? The initial status will be Pending Confirmation.';
  final String confirmDialogCancel = 'Cancel';
  final String confirmDialogAccept = 'Confirm Submit';
  final String cancelButton = 'Cancel Booking Request';
  final String cancelDialogTitle = 'Cancel Booking Request';
  final String cancelDialogBody =
      'Are you sure you want to cancel this booking request?';
  final String cancelDialogKeep = 'Keep Booking';
  final String cancelDialogConfirm = 'Confirm Cancellation';
  final String cancelSuccessNotice =
      'Cancellation recorded. If a payment had been collected, any refund would be returned through the original payment channel.';
  final String productionPendingNotice =
      'Commercial service booking submission is pending server integration. Live backend bookings are not yet enabled.';
  final String statusPendingConfirmation = 'Pending Confirmation';
  final String statusConfirmed = 'Confirmed';
  final String statusRejected = 'Rejected';
  final String statusCancelled = 'Cancelled';
  final String newRequestButton = 'Submit Another Request';
  final String optionPrefix = 'Option:';
  final String dateTimePrefix = 'Date & Time:';
  final String quantityPrefix = 'Quantity:';
  final String itineraryReflectionNotice =
      'Confirmed service is reflected in your booking history and linked itinerary stop.';
}

final class _MessageStrings {
  const _MessageStrings();

  final String requiredField = 'This field is required.';
  final String poiInactive =
      'This point of interest is no longer active or does not exist.';
  final String requestCreated =
      'Your booking request has been created with status Pending Confirmation and transmitted to the commercial service provider.';
  final String availabilityUnavailable =
      'The requested date or requested time is not available for this service.';
  final String quantityExceeded =
      'The requested quantity exceeds the available quantity for this service.';
  final String providerConfirmed =
      'The commercial service provider has confirmed your booking request. The confirmed service is now reflected in your associated itinerary.';
  final String providerRejected =
      'The commercial service provider has rejected your booking request. No service has been reserved.';
  final String requestCancelled =
      'Your booking request has been cancelled. If a payment had been collected, any refund would be returned through the original payment channel.';
  final String serviceClosed =
      'This commercial service is not currently open for booking.';
  final String requestedDatePast = 'The requested date cannot be in the past.';
  final String permissionDenied =
      'You do not have permission to access this function.';
  final String systemError =
      'TripMate is temporarily unable to process your request. Please check your connection and try again.';
  final String ordinaryPoiNoBooking =
      'Commercial booking is not available for this point of interest.';
}

final class _DemoStrings {
  const _DemoStrings();

  final String controlsTitle = 'Demo Provider Simulation Controls';
  final String simulateConfirmButton = 'Simulate Provider Confirm';
  final String simulateRejectButton = 'Simulate Provider Reject';
  final String simulateClosedService = 'Simulate Closed Service';
  final String simulateSlotUnavailable = 'Simulate Slot Unavailable';
  final String simulateSystemFailure = 'Simulate System Failure';
  final String scenarioInactivePoi = 'Inactive POI';
  final String scenarioClosedForBooking = 'Closed for Booking';
  final String scenarioSystemFailure = 'System Failure';
}

final class _AccessibilityStrings {
  const _AccessibilityStrings();

  final String backButtonTooltip = 'Back';
  final String clearSearchTooltip = 'Clear search';
  final String decreaseQuantityTooltip = 'Decrease quantity';
  final String increaseQuantityTooltip = 'Increase quantity';
  final String quantitySelectedLabel = 'Selected quantity';
  final String closeMapTooltip = 'Close map';
}
