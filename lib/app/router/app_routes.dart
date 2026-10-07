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
  static const traveler = '/traveler';
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
  static const commercialServicesSearch = '/traveler/services';
  static const commercialServicesSearchPattern = commercialServicesSearch;
  static const commercialServiceDetailPattern = '/traveler/services/:poiId';
  static const commercialServiceBookingPattern =
      '/traveler/services/:poiId/book';
  static const operator = '/operator';
  static const operatorApplication = '/operator/application';
  static const createCoupon = '/operator/coupons/create';

  static String activeTripLive(int itineraryId) =>
      '/traveler/trips/$itineraryId/live';
  static String tripAlerts(int itineraryId) =>
      '/traveler/trips/$itineraryId/alerts';
  static String offlinePackage(int itineraryId) =>
      '/traveler/trips/$itineraryId/offline';
  static String groupLocationSharingPath(int groupId) =>
      '/traveler/groups/$groupId/location-sharing';
  static String poiDetail(int id) => '/explore/poi/$id';
  static String commercialServicesSearchPath({
    String? search,
    String? category,
    bool demo = false,
  }) {
    final query = <String, String>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (demo) 'demo': 'true',
    };
    return Uri(
      path: commercialServicesSearch,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static String commercialServiceDetail(
    int poiId, {
    String? intendedDate,
    bool demo = false,
  }) {
    final query = <String, String>{
      if (intendedDate != null && intendedDate.trim().isNotEmpty)
        'intendedDate': intendedDate.trim(),
      if (demo) 'demo': 'true',
    };
    return Uri(
      path: '/traveler/services/$poiId',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

  static String commercialServiceBooking(
    int poiId, {
    String? optionId,
    String? intendedDate,
    bool demo = false,
  }) {
    final query = <String, String>{
      if (optionId != null && optionId.trim().isEmpty == false)
        'optionId': optionId.trim(),
      if (intendedDate != null && intendedDate.trim().isNotEmpty)
        'intendedDate': intendedDate.trim(),
      if (demo) 'demo': 'true',
    };
    return Uri(
      path: '/traveler/services/$poiId/book',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }

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
  static const traveler = 'traveler';
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
  static const commercialServicesSearch = 'commercial-services-search';
  static const commercialServiceDetail = 'commercial-service-detail';
  static const commercialServiceBooking = 'commercial-service-booking';
  static const operator = 'operator';
  static const operatorApplication = 'operator-application';
  static const createCoupon = 'create-coupon';
}
