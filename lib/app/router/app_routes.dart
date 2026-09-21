abstract final class AppRoutes {
  static const splash = '/';
  static const home = traveler;
  static const login = '/auth/login';
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
  static const createTravelGroup = '/traveler/groups/create';
  static const joinTravelGroup = '/traveler/groups/join';
  static const travelerTravelGroups = '/traveler/groups';
  static const travelGroupDetails = '/traveler/groups/:groupId';
  static const inviteGroupMembers = '/traveler/groups/:groupId/invitation';
  static const operator = '/operator';
  static const operatorApplication = '/operator/application';

  static String poiDetail(int id) => '/explore/poi/$id';
  static const authPrefix = '/auth';
  static const travelerPrefix = '/traveler';
  static const operatorPrefix = '/operator';
}

abstract final class AppRouteNames {
  static const splash = 'splash';
  static const login = 'login';
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
  static const createTravelGroup = 'create-travel-group';
  static const joinTravelGroup = 'join-travel-group';
  static const travelGroupDetails = 'travel-group-details';
  static const inviteGroupMembers = 'invite-group-members';
  static const operator = 'operator';
  static const operatorApplication = 'operator-application';
}
