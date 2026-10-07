/// English resource strings for UC-30 and UC-31 commercial service features,
/// satisfying Report 3 V2 CR-09 (English UI language and centralized resources).
///
/// Notice on SRS Internal Conflicts:
///
/// 1. SRS_INTERNAL_CONFLICT_COMMERCIAL_BR_IDS:
/// Detailed UC-30 / UC-31 define:
/// - BR-87: exactly Hotel, Vehicle Rental, Restaurant
/// - BR-34: POI detail only while POI is Active
/// - BR-88 (UC-30): service shown as bookable only when open for booking and intended-date availability can be retrieved
/// - BR-55 (UC-30): availability is retrieved at display time and is NOT a reservation
/// - BR-88 (UC-31): requested date/time/quantity must be within published availability
/// - BR-89 (UC-31): request starts Pending Confirmation and only becomes Confirmed after provider confirmation
/// - BR-63 (UC-31): estimated amount computed by TripMate; client amount ignored
/// - BR-76 (UC-31): refund returns through original payment channel if payment was collected
///
/// Appendix 5.1 defines duplicate/reused identifiers with differing definitions:
/// - BR-34: if Traveler rejects rerouting proposal, active itinerary/route continues unchanged and Incident remains for audit
/// - BR-55: updated POI/Route data propagates immediately to consuming itinerary/navigation functions
/// - BR-63: booking record captures Traveler ID, Tour ID, Tour Operator ID, requested slots, price, initial status and creation timestamp
/// - BR-76: refund may only be initiated for an eligible cancelled booking under refund policy
/// - BR-87: commercial services limited to Hotel / Vehicle Rental / Restaurant and each is represented as a POI in the centralized catalog (largely compatible)
/// - BR-88: commercial booking may reference only a POI in one of the supported commercial categories
/// - BR-89: commercial booking may originate from itinerary or POI catalog and must store the correct referenced POI
///
/// 2. SRS_INTERNAL_CONFLICT_COMMERCIAL_MESSAGE_IDS:
/// Detailed UC-31 defines:
/// - MSG01: required field missing
/// - MSG76: requested date is in the past
/// - MSG70: requested date or requested time unavailable
/// - MSG71: requested quantity exceeds available quantity
/// - MSG75: service no longer open for booking
/// - MSG69: booking request created successfully
/// - MSG72: provider confirms request
/// - MSG73: provider rejects request
/// - MSG74: Traveler cancels request
/// - MSG127: request creation/system failure
///
/// Appendix 5.3 separately reuses MSG69–MSG76 for Tour Package operations.
/// Numeric BR and MSG identifiers are strictly excluded from user-facing copy.
abstract final class CommercialServiceEn {
  static const search = _SearchStrings();
  static const detail = _DetailStrings();
  static const booking = _BookingStrings();
  static const messages = _MessageStrings();
  static const demo = _DemoStrings();
  static const a11y = _AccessibilityStrings();
  static const accessibility = _AccessibilityStrings();
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
  final String poiDetailTitle = 'Point of Interest Detail';
  final String poiUnavailableTitle = 'Point of Interest Unavailable';
  final String unableToLoadTitle = 'Unable to Load Commercial Service';
  final String serviceInformation = 'Service Information';
  final String categoryLabel = 'Category';
  final String addressLabel = 'Address';
  final String addressNotProvided = 'Address not provided';
  final String coordinatesLabel = 'Coordinates';
  final String contactInformationLabel = 'Contact Information';
  final String priceRangeLabel = 'Price Range';
  final String pendingNotReturnedByPoi =
      'Pending Server Integration (Not returned by POI endpoint)';
  final String openingHoursTitle = 'Opening Hours';
  final String viewOnMap = 'View on Map';
  final String returnToDetail = 'Return to Commercial Service Detail';
  final String ordinaryPoiBadge = 'Ordinary POI (Non-Commercial)';
  final String productionPartialSemantics =
      'Production Partial Backend Notice: Base POI details are live from Backend, while commercial options, pricing, and display-time availability are pending server integration.';
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
  final String menuHighlights = 'Menu Highlights:';
  final String closed = 'Closed';

  List<String> get daysOfWeek => const [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  String categorySpecificPendingNotice(
    String specificSectionTitle,
    String unitLabel,
  ) =>
      'Pending Server Integration — $specificSectionTitle and bookable service options are not returned by GET /api/v1/pois/{id}. No fake $unitLabel are displayed in Production.';

  String tableCapacity(int capacity) => 'Table Capacity: $capacity seats';

  String availableOnDate(String dateIso, int units) =>
      'Available on $dateIso ($units units open)';

  String noAvailabilityOnDate(String dateIso) => 'No availability on $dateIso';

  String timeSlots(String slots) => 'Time slots: $slots';

  String coordinatesValue(double lat, double lng) =>
      'Coordinates: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

  String photoCount(int count) => '$count photo(s)';
}

final class _BookingStrings {
  const _BookingStrings();

  final String title = 'Commercial Service Booking';
  final String unselectedOption = 'Unselected option';
  final String bookingDetails = 'Booking Details';
  final String selectedOptionLabel = 'Selected Service Option *';
  final String requestedDateLabel = 'Requested Date (YYYY-MM-DD) *';
  final String requestedDateHint = '2026-10-15';
  final String requestedTimeLabel = 'Requested Time (HH:mm) *';
  final String requestedTimeHint = '14:00';
  final String availableUnitsPrefix = 'Available:';
  final String quantityLabel = 'Quantity *';
  final String specialRequestsLabel = 'Special Request (Optional)';
  final String specialRequestsHint =
      'Early check-in, dietary preference, child seat...';
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
  final String submitButton = 'Submit Request';
  final String submitButtonDisabledSemantics =
      'Submit Request disabled pending server integration';
  final String productionPendingSemantics =
      'Pending Server Integration: Commercial service booking API is not available in Production.';
  final String serviceSummaryTitle = 'Service Summary';
  final String serviceNameLabel = 'Service Name';
  final String categoryLabel = 'Category';
  final String addressLabel = 'Address';
  final String addressPending = 'Address pending server integration';
  final String priceInformationLabel = 'Price Information';
  final String pricingNotReturnedNotice =
      'Pending Server Integration — Commercial pricing is not returned by GET /api/v1/pois/{id}.';
  final String noBookableOptionsNotice =
      'Pending Server Integration — No bookable service options are available in Production.';
  final String bookingRequestPrefix = 'Booking Request';
  final String selectedOptionSummaryLabel = 'Selected Option';
  final String dateTimeSummaryLabel = 'Date & Time';
  final String quantitySummaryLabel = 'Quantity';
  final String contactSummaryLabel = 'Contact';
  final String cancelPendingRequestButton = 'Cancel Pending Request';

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

  String serviceNameFallback(int poiId) => 'Commercial Service (POI #$poiId)';

  String cancelDialogBodyWithDetails(String requestId, String serviceName) =>
      'Are you sure you want to cancel request $requestId for $serviceName?';
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
  final String demoModeHeader =
      'DEMO MODE (kDebugMode && ?demo=true) — UC-30 Scenarios';
  final String presetDateAvailable = 'Date: 2026-10-15 (Available)';
  final String presetDateUnavailable = 'Date: 2026-10-20 (Unavailable)';
  final String presetPastDate = 'Set Past Date (2020-01-01)';
  final String presetValidDate = 'Set Valid Date (2026-10-15)';
}

final class _AccessibilityStrings {
  const _AccessibilityStrings();

  final String backButtonTooltip = 'Back';
  final String clearSearchTooltip = 'Clear search';
  final String decreaseQuantityTooltip = 'Decrease quantity';
  final String increaseQuantityTooltip = 'Increase quantity';
  final String quantitySelectedLabel = 'Selected quantity';
  final String closeMapTooltip = 'Close map';

  String bookServiceForSemantics(String poiName) => 'Book Service for $poiName';

  String bookServiceDisabledSemantics(String poiName) =>
      'Book Service disabled for $poiName';

  String selectOptionSemantics(
    String name,
    String priceVnd,
    String unit,
    int qty,
  ) => 'Select $name, $priceVnd per $unit, $qty available';

  String availableDateSemantics(String dateIso, int units) =>
      'Available on $dateIso with $units units';

  String unavailableDateSemantics(String dateIso) => 'Unavailable on $dateIso';

  String mapMarkerFor(String poiName) => 'Map marker for $poiName';

  String galleryPhotoFor(String poiName) => 'Gallery photo for $poiName';
}
