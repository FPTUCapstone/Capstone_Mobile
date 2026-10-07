/// English strings for UC-32 (Trip History) and UC-33 (Trip Review).
///
/// CR-09 compliance: All user-facing text is resource-backed.
/// Numeric BR and MSG identifiers are strictly internal and must not be
/// rendered to end users.
abstract final class TripHistoryStringsEn {
  // Screen Titles
  static const String tripHistoryTitle = 'Trip History';
  static const String tripReviewTitle = 'Trip Review & Rating';
  static const String editReviewTitle = 'Edit Trip Review';
  static const String viewReviewTitle = 'Trip Review';

  // Tabs
  static const String tabUpcoming = 'Upcoming';
  static const String tabCompleted = 'Completed';
  static const String tabCancelled = 'Cancelled';

  // Filters
  static const String filterDateRange = 'Date Range';
  static const String filterStartDate = 'Start Date';
  static const String filterEndDate = 'End Date';
  static const String filterSelectDates = 'Select dates';
  static const String filterClearDates = 'Clear dates';
  static const String filterTripType = 'Trip Type';
  static const String filterAll = 'All';
  static const String filterTour = 'Tour';
  static const String filterCommercialService = 'Commercial Service';
  static const String filterItinerary = 'Itinerary';
  static const String filterApply = 'Apply Filters';
  static const String filterReset = 'Reset';

  // List Item Fields & Labels
  static const String labelBookingCode = 'Booking Code';
  static const String labelDepartureDate = 'Departure Date';
  static const String labelParticipants = 'Participants';
  static const String labelTotalAmount = 'Total Amount';
  static const String labelFree = 'Free';
  static const String labelStatus = 'Status';
  static const String labelType = 'Type';

  // Participant formatting
  static String formatParticipants(int count) =>
      count == 1 ? '1 participant' : '$count participants';

  // Status Labels
  static const String statusConfirmed = 'Confirmed';
  static const String statusOngoing = 'Ongoing';
  static const String statusCompleted = 'Completed';
  static const String statusCancelled = 'Cancelled';

  // Contextual Actions per Record
  static const String actionViewEticket = 'View E-ticket';
  static const String actionWriteReview = 'Write Review';
  static const String actionEditReview = 'Edit Review';
  static const String actionViewReview = 'View Review';
  static const String actionViewRefundStatus = 'View Refund Status';
  static const String actionViewDetails = 'View Details';
  static const String actionCancel = 'Cancel';
  static const String actionClose = 'Close';
  static const String actionSubmitReview = 'Submit Review';
  static const String actionSaveReview = 'Save Changes';
  static const String actionAddPhoto = 'Add Photo';
  static const String actionRemovePhoto = 'Remove';
  static const String actionRetry = 'Retry';

  // Action Notices & Tooltips
  static const String noticeEticketPending =
      'E-ticket service is currently being integrated. Please check back soon.';
  static const String noticeReviewNotCompleted =
      'Reviews can only be submitted for completed trips.';
  static const String noticeReviewAlreadyExists =
      'A review has already been submitted for this booking.';
  static const String noticeSelfPlannedNoReview =
      'Reviews are not applicable to self-planned itineraries.';

  // Refund Status Dialog
  static const String refundDialogTitle = 'Refund Status';
  static const String refundState = 'Refund State';
  static const String refundedAmount = 'Refunded Amount';
  static const String refundChannel = 'Refund Channel';
  static const String refundNote = 'Note';
  static const String refundStateRefunded = 'Refunded';
  static const String refundStateProcessing = 'Processing';
  static const String refundStateNonRefundable = 'Non-refundable';

  // Details Dialog
  static const String detailsDialogTitle = 'Booking Details';
  static const String detailsProvider = 'Provider';
  static const String detailsLocation = 'Location';

  // Pagination
  static const String paginationPrevious = 'Previous';
  static const String paginationNext = 'Next';
  static String formatPagination(int page, int totalPages) =>
      'Page $page of $totalPages';

  // Empty & Error States (UC-32)
  static const String emptyListMessage =
      'No records found matching your criteria.';
  static const String errorMessageGeneric =
      'TripMate is temporarily unable to process your request. Please check your connection and try again.';
  static const String validationDateRangeInvalid =
      'The end date cannot be earlier than the start date.';
  static const String permissionDenied =
      'You do not have permission to access this function.';

  // Screen #74 Review Form
  static const String summarySectionTitle = 'Trip Information';
  static const String summaryTourOrService = 'Tour / Service';
  static const String ratingSectionTitle = 'Rating';
  static const String ratingPrompt = 'Select your rating';
  static const String reviewTitleLabel = 'Review Title';
  static const String reviewTitleHint = 'Summarize your trip experience';
  static const String reviewContentLabel = 'Review Content';
  static const String reviewContentHint =
      'Share details of your experience to help fellow travelers...';
  static const String photoSectionTitle = 'Photos (Optional)';
  static const String photoSectionSubtitle =
      'Attach up to 5 photos (max 5 MB each)';
  static const String photoPickMockTitle = 'Select photo to attach:';
  static const String photoValidSample = 'Scenic view (valid, 2.1 MB)';
  static const String photoOversizedSample =
      'High-res panorama (oversized, 6.4 MB)';
  static const String photoUnsupportedSample =
      'Travel document (unsupported format, 1.5 MB)';

  // Review Validation & Feedback Messages (UC-33)
  static const String validationRatingRequired =
      'Please select a rating between 1 and 5 stars.';
  static const String validationFieldRequired = 'This field is required.';
  static const String validationPhotoInvalidType =
      'Only JPEG, PNG, and WebP image formats are supported.';
  static const String validationPhotoExceedsLimit =
      'Attached photos must be valid image files and must not exceed 5 MB.';
  static const String validationPhotoMaxCount =
      'You can attach a maximum of 5 photos.';
  static const String validationContentPolicyViolation =
      'Your review content violates our content policy and cannot be published.';
  static const String reviewReadOnlyNotice =
      'The 7-day edit window has expired. This review is now read-only.';
  static const String reviewEditWindowActive =
      'You can edit your review within 7 days of submission.';
  static const String reviewSubmitSuccess = 'Review submitted successfully.';
  static const String reviewUpdateSuccess = 'Review updated successfully.';

  // Production Integration Notice
  static const String productionIntegrationPending =
      'Trip service integration is in progress. Historical bookings will appear once live backend service is connected.';
  static const String productionReviewMutationDisabled =
      'Review submissions are temporarily disabled pending backend integration.';

  // Accessibility Labels
  static const String a11yStarRating = 'Rate {star} of 5 stars';
  static const String a11ySelectedRating = 'Selected {rating} stars';
  static const String a11yTripCard =
      'Trip {name}, {status}, departure on {date}';
  static const String a11yFilterTab = '{tab} trips tab';
}
