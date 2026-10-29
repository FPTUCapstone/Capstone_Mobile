abstract final class AppRoutes {
  static const splash = '/';
  static const home = traveler;
  static const login = '/auth/login';
  static const forgotPassword = '/auth/forgot-password';
  static const travelerRegistration = '/auth/register/traveler';
  static const verifyEmail = '/auth/verify-email';
  static const operatorRegistration = '/auth/register/operator';
  static const operatorEmailRecovery = '/auth/operator/verify-email';
  static const explore = '/explore';
  static const guestHome = '/guest/home';
  static const poiDetailPattern = '/explore/poi/:id';
  static const tourSearch = '/explore/tours';
  static const tourDetailPattern = '/explore/tours/:tourId';
  static const bookTourPattern = '/explore/tours/:tourId/book';
  static const paymentPattern = '/payment/:bookingId';
  static const bookingRefundPattern = '/bookings/:bookingId/refund';
  static String payment(
    String bookingId, {
    String? bookingCode,
    int? amount,
    String? currency,
  }) {
    final params = <String, String>{};
    if (bookingCode != null) params['code'] = bookingCode;
    if (amount != null) params['amount'] = amount.toString();
    if (currency != null) params['currency'] = currency;
    return Uri(
      path: '/payment/$bookingId',
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }

  static String bookingRefund(String bookingId) =>
      '/bookings/$bookingId/refund';

  static const traveler = '/traveler';
  static const tourRecommendations = '/traveler/tours/recommendations';
  static const travelerSettings = '/traveler/settings';
  static const inAppInbox = '/traveler/notifications';
  static const travelerProfile = '/traveler/profile';
  static const travelerPreferences = '/traveler/preferences';
  static const travelerChangePassword = '/traveler/change-password';
  static const createItinerary = '/traveler/itineraries/create';
  static const itineraryResult = '/traveler/itineraries/result';
  static const itineraryDetail = '/traveler/itineraries/:itineraryId';
  static const createTravelGroup = '/traveler/groups/create';
  static const joinTravelGroup = '/traveler/groups/join';
  static const travelerTravelGroups = '/traveler/groups';
  static const travelGroupDetails = '/traveler/groups/:groupId';
  static const inviteGroupMembers = '/traveler/groups/:groupId/invitation';
  static const travelGroupMembers = '/traveler/groups/:groupId/members';
  static const groupLocationSharing =
      '/traveler/groups/:groupId/location-sharing';
  static const activeTripLivePattern = '/traveler/trips/:itineraryId/live';
  static const tripAlertsPattern = '/traveler/trips/:itineraryId/alerts';
  static const offlinePackagePattern = '/traveler/trips/:itineraryId/offline';
  static const tripHistory = '/traveler/trips';
  static const eTicketPattern = '/traveler/tickets/:ticketId';
  static const bookingETicketPattern = '/traveler/bookings/:bookingId/ticket';
  static const tripReviewPattern = '/traveler/trips/:tripId/review';
  static const canonicalTripReviewPattern = '/traveler/reviews/:kind/:id';
  static const operator = '/operator';
  static const operatorApplication = '/operator/application';
  static const operatorApplicationResubmit = '/operator/application/resubmit';
  static const createCoupon = '/operator/coupons/create';
  static const operatorChangePassword = '/operator/change-password';
  static const createTourPackage = '/operator/tours/create';
  static const operatorTours = '/operator/tours';
  static const operatorBooking = '/operator/bookings/:bookingId';
  static const operatorCheckIn = '/operator/check-in';
  static String operatorCheckInPath({int? scheduleId, bool isDemo = false}) {
    final params = <String, String>{};
    if (scheduleId != null) params['scheduleId'] = scheduleId.toString();
    if (isDemo) params['demo'] = 'true';
    return Uri(
      path: operatorCheckIn,
      queryParameters: params.isEmpty ? null : params,
    ).toString();
  }
  static String operatorBookingPath(String bookingId, {bool isDemo = false}) =>
      '/operator/bookings/$bookingId${isDemo ? '?demo=true' : ''}';
  static const editTourPackage = '/operator/tours/:tourId/edit';
  static String editTourPackagePath(int tourId) =>
      '/operator/tours/$tourId/edit';

  static String itineraryDetailPath(int itineraryId) =>
      '/traveler/itineraries/$itineraryId';
  static String activeTripLive(int itineraryId) =>
      '/traveler/trips/$itineraryId/live';
  static String tripAlerts(int itineraryId) =>
      '/traveler/trips/$itineraryId/alerts';
  static String offlinePackage(int itineraryId) =>
      '/traveler/trips/$itineraryId/offline';

  /// UC-29: the e-ticket linked from Trip History (`actions.ticketId`).
  static String eTicket(int ticketId) => '/traveler/tickets/$ticketId';

  /// UC-29: the e-ticket of a booking, opened after a successful payment.
  static String bookingETicket(int bookingId) =>
      '/traveler/bookings/$bookingId/ticket';
  static String tripHistoryPath({bool isDemo = false}) =>
      isDemo ? '/traveler/trips?demo=true' : '/traveler/trips';
  static String tripReview(String tripId, {bool isDemo = false}) => isDemo
      ? '/traveler/trips/$tripId/review?demo=true'
      : '/traveler/trips/$tripId/review';
  static String canonicalTripReview(String kind, int id) =>
      '/traveler/reviews/$kind/$id';
  static String groupLocationSharingPath(int groupId) =>
      '/traveler/groups/$groupId/location-sharing';
  static String poiDetail(int id) => '/explore/poi/$id';
  static String tourDetail(String tourId, {bool demo = false}) =>
      demo ? '/explore/tours/$tourId?demo=true' : '/explore/tours/$tourId';
  static String bookTour(String tourId, String scheduleId) => Uri(
    path: '/explore/tours/$tourId/book',
    queryParameters: {'scheduleId': scheduleId},
  ).toString();
  static const authPrefix = '/auth';
  static const travelerPrefix = '/traveler';
  static const operatorPrefix = '/operator';
}

abstract final class AppRouteNames {
  static const splash = 'splash';
  static const login = 'login';
  static const forgotPassword = 'forgot-password';
  static const travelerRegistration = 'traveler-registration';
  static const verifyEmail = 'verify-email';
  static const operatorRegistration = 'operator-registration';
  static const operatorEmailRecovery = 'operator-email-recovery';
  static const explore = 'explore';
  static const guestHome = 'guest-home';
  static const poiDetail = 'poi-detail';
  static const tourSearch = 'tour-search';
  static const tourDetail = 'tour-detail';
  static const bookTour = 'book-tour';
  static const payment = 'payment';
  static const bookingRefund = 'booking-refund';
  static const traveler = 'traveler';
  static const tourRecommendations = 'tour-recommendations';
  static const travelerSettings = 'traveler-settings';
  static const inAppInbox = 'in-app-inbox';
  static const travelerProfile = 'traveler-profile';
  static const travelerPreferences = 'traveler-preferences';
  static const travelerChangePassword = 'traveler-change-password';
  static const createItinerary = 'create-itinerary';
  static const itineraryResult = 'itinerary-result';
  static const itineraryDetail = 'itinerary-detail';
  static const createTravelGroup = 'create-travel-group';
  static const joinTravelGroup = 'join-travel-group';
  static const travelGroupDetails = 'travel-group-details';
  static const inviteGroupMembers = 'invite-group-members';
  static const travelGroupMembers = 'travel-group-members';
  static const groupLocationSharing = 'group-location-sharing';
  static const activeTripLive = 'active-trip-live';
  static const tripAlerts = 'trip-alerts';
  static const offlinePackage = 'offline-package';
  static const tripHistory = 'trip-history';
  static const eTicket = 'e-ticket';
  static const bookingETicket = 'booking-e-ticket';
  static const tripReview = 'trip-review';
  static const operator = 'operator';
  static const operatorApplication = 'operator-application';
  static const operatorApplicationResubmit = 'operator-application-resubmit';
  static const createCoupon = 'create-coupon';
  static const operatorChangePassword = 'operator-change-password';
  static const createTourPackage = 'create-tour-package';
  static const operatorTours = 'operator-tours';
  static const operatorBooking = 'operator-booking';
  static const operatorCheckIn = 'operator-check-in';
  static const editTourPackage = 'edit-tour-package';
}
