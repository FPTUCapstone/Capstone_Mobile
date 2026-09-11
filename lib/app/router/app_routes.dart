abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/auth/login';
  static const travelerRegistration = '/auth/register/traveler';
  static const operatorRegistration = '/auth/register/operator';
  static const resetPassword = '/auth/reset-password';
  static const traveler = '/traveler';
  static const travelerSettings = '/traveler/settings';
  static const travelerProfile = '/traveler/profile';
  static const travelerPreferences = '/traveler/preferences';
  static const travelerChangePassword = '/traveler/change-password';
  static const createTravelGroup = '/traveler/groups/create';
  static const inviteGroupMembers = '/traveler/groups/:groupId/invitation';
  static const operator = '/operator';
  static const operatorApplication = '/operator/application';

  static const demoIndex = '/demo';
  static const demoUc01 = '/demo/uc-01';
  static const demoUc02 = '/demo/uc-02';
  static const demoUc03 = '/demo/uc-03';
  static const demoUc04 = '/demo/uc-04';
  static const demoUc05 = '/demo/uc-05';
  static const demoUc06 = '/demo/uc-06';
  static const demoUc07 = '/demo/uc-07';
  static const demoUc08 = '/demo/uc-08';
  static const demoUc09 = '/demo/uc-09';
  static const demoUc17 = '/demo/uc-17';

  static const authPrefix = '/auth';
  static const travelerPrefix = '/traveler';
  static const operatorPrefix = '/operator';
}

abstract final class AppRouteNames {
  static const splash = 'splash';
  static const login = 'login';
  static const travelerRegistration = 'traveler-registration';
  static const operatorRegistration = 'operator-registration';
  static const resetPassword = 'reset-password';
  static const traveler = 'traveler';
  static const travelerSettings = 'traveler-settings';
  static const travelerProfile = 'traveler-profile';
  static const travelerPreferences = 'traveler-preferences';
  static const travelerChangePassword = 'traveler-change-password';
  static const createTravelGroup = 'create-travel-group';
  static const inviteGroupMembers = 'invite-group-members';
  static const operator = 'operator';
  static const operatorApplication = 'operator-application';
  static const demoIndex = 'demo-index';
}
