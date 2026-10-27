/// English strings for UC-40 (Tour Operator Customer Bookings).
///
/// CR-09: every user-facing text is resource-backed. The messages that have an SRS catalogue entry use the
/// catalogue wording; message ids themselves are internal and are never rendered.
abstract final class OperatorBookingsStringsEn {
  // Messages (SRS catalogue wording)

  /// MSG126: the booking, tour or role is not accessible to this operator.
  static const String accessDenied =
      'You do not have permission to access this function.';

  /// MSG127: generic network or server failure.
  static const String systemError =
      'TripMate is temporarily unable to process your request. '
      'Please check your connection and try again.';

  /// MSG128: the list has no result for the applied filters.
  static const String noRecords = 'No records found matching your criteria.';

  /// MSG31: the departure range is inverted.
  static const String dateRangeInvalid =
      'End date must be on or after the start date.';

  // Common
  static const String retry = 'Retry';
  static const String close = 'Close';
  static const String notAvailable = '-';

  // List screen (#84)
  static const String listTitle = 'Customer bookings';
  static const String emptyTitle = 'No bookings found';
  static const String searchHint = 'Search by code, name or e-mail';
  static const String filtersButton = 'Filters';
  static const String loadMore = 'Load more';
  static const String loadingMore = 'Loading...';
  static const String demoBanner =
      'Demo data: these bookings are samples, not live data.';
  static const String summaryBookings = 'Bookings';
  static const String summaryBookingsHint = 'Matching the filters';
  static const String summaryParticipants = 'Participants';
  static const String summaryParticipantsHint = 'Confirmed and completed';
  static const String summaryRevenue = 'Confirmed revenue';
  static const String summaryRevenueHint = 'Confirmed and completed';
  static const String cardDeparture = 'Departure';
  static const String cardBooker = 'Booker';
  static const String cardParticipants = 'Participants';
  static const String cardTotal = 'Total';
  static const String cardOpenDetails = 'View details';

  // Status chips and badges
  static const String statusAll = 'All';
  static const String statusPendingPayment = 'Pending payment';
  static const String statusConfirmed = 'Confirmed';
  static const String statusCancelled = 'Cancelled';
  static const String statusCompleted = 'Completed';
  static const String statusExpired = 'Expired';
  static const String paymentUnpaid = 'Unpaid';
  static const String paymentPaid = 'Paid';
  static const String paymentRefunded = 'Refunded';
  static const String paymentPartiallyRefunded = 'Partially refunded';
  static const String checkedIn = 'Checked in';
  static const String notCheckedIn = 'Not checked in';

  // Filter sheet
  static const String filterTitle = 'Filters';
  static const String filterTour = 'Tour';
  static const String filterAllTours = 'All tours';
  static const String filterToursUnavailable =
      'The tour list is unavailable right now; showing all tours.';
  static const String filterDepartureFrom = 'Departure from';
  static const String filterDepartureTo = 'Departure to';
  static const String filterSelectDate = 'Select date';
  static const String filterClearDate = 'Clear date';
  static const String filterApply = 'Apply';
  static const String filterReset = 'Reset';

  // Detail screen (#85)
  static const String detailTitle = 'Booking details';
  static const String detailTour = 'Tour';
  static const String detailDeparture = 'Departure';
  static const String detailMeetingPoint = 'Meeting point';
  static const String detailCheckIn = 'Check-in';
  static const String detailCheckedInAt = 'Checked in at';
  static const String detailBookedAt = 'Booked at';
  static const String detailBooker = 'Booker';
  static const String detailPhone = 'Phone';
  static const String detailEmail = 'E-mail';
  static const String detailManifest = 'Passenger manifest';
  static const String detailTicket = 'E-ticket';
  static const String detailTicketCode = 'Ticket code';
  static const String detailTicketStatus = 'Ticket status';
  static const String detailPayment = 'Payment (read-only)';
  static const String detailGateway = 'Gateway';
  static const String detailReference = 'Transaction reference';
  static const String detailPaidAt = 'Paid at';
  static const String detailAmount = 'Amount';
  static const String detailPricing = 'Pricing';
  static const String detailPaymentStatus = 'Payment status';
  static const String detailPaidAmount = 'Paid amount';
  static const String detailSubtotal = 'Subtotal';
  static const String detailDiscount = 'Discount';
  static const String detailCoupon = 'Coupon';
  static const String detailTotal = 'Total';
  static const String detailCancellation = 'Cancellation';
  static const String detailCancelledAt = 'Cancelled at';
  static const String detailCancelReason = 'Reason';

  // Participant types
  static const String participantAdult = 'Adult';
  static const String participantChild = 'Child';
  static const String participantInfant = 'Infant';

  // Ticket statuses
  static const String ticketValid = 'Valid';
  static const String ticketUsed = 'Used';
  static const String ticketCancelled = 'Cancelled';
  static const String ticketExpired = 'Expired';
}
