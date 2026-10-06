abstract final class AppRoutes {
  static const splash = '/';
  static const home = traveler;
  static const login = '/auth/login';
  static const forgotPassword = '/auth/forgot-password';
  static const travelerRegistration = '/auth/register/traveler';
  static const verifyEmail = '/auth/verify-email';
  static const operatorRegistration = '/auth/register/operator';
  static const explore = '/explore';
  static const poiDetailPattern = '/explore/poi/:id';
  static const tourSearch = '/explore/tours';
  static const tourDetailPattern = '/explore/tours/:tourId';
  static const traveler = '/traveler';
  static const tourRecommendations = '/traveler/tours/recommendations';
  static const bookTourPattern = '/traveler/tours/:tourId/book';
  static const bookingPaymentPattern = '/traveler/bookings/:bookingId/payment';
  static const bookingEticketPattern = '/traveler/bookings/:bookingId/eticket';
  static const travelerSettings = '/traveler/settings';
  static const travelerProfile = '/traveler/profile';
  static const travelerPreferences = '/traveler/preferences';
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
  static const operator = '/operator';
  static const operatorApplication = '/operator/application';

  static String activeTripLive(int itineraryId) =>
      '/traveler/trips/$itineraryId/live';
  static String tripAlerts(int itineraryId) =>
      '/traveler/trips/$itineraryId/alerts';
  static String offlinePackage(int itineraryId) =>
      '/traveler/trips/$itineraryId/offline';
  static String groupLocationSharingPath(int groupId) =>
      '/traveler/groups/$groupId/location-sharing';
  static String poiDetail(int id) => '/explore/poi/$id';
  static String tourDetail(String tourId, {bool demo = false}) =>
      demo ? '/explore/tours/$tourId?demo=true' : '/explore/tours/$tourId';
  static String bookTour(
    String tourId, {
    String? scheduleId,
    bool demo = false,
  }) {
    final query = <String, String>{
      if (scheduleId != null && scheduleId.isNotEmpty) 'scheduleId': scheduleId,
      if (demo) 'demo': 'true',
    };
    if (query.isEmpty) return '/traveler/tours/$tourId/book';
    return Uri(
      path: '/traveler/tours/$tourId/book',
      queryParameters: query,
    ).toString();
  }

  static String bookingPayment(String bookingId, {bool demo = false}) => demo
      ? '/traveler/bookings/$bookingId/payment?demo=true'
      : '/traveler/bookings/$bookingId/payment';
  static String bookingEticket(String bookingId, {bool demo = false}) => demo
      ? '/traveler/bookings/$bookingId/eticket?demo=true'
      : '/traveler/bookings/$bookingId/eticket';
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
  static const explore = 'explore';
  static const poiDetail = 'poi-detail';
  static const tourSearch = 'tour-search';
  static const tourDetail = 'tour-detail';
  static const traveler = 'traveler';
  static const tourRecommendations = 'tour-recommendations';
  static const bookTour = 'book-tour';
  static const bookingPayment = 'booking-payment';
  static const bookingEticket = 'booking-eticket';
  static const travelerSettings = 'traveler-settings';
  static const travelerProfile = 'traveler-profile';
  static const travelerPreferences = 'traveler-preferences';
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
  static const operator = 'operator';
  static const operatorApplication = 'operator-application';
}
