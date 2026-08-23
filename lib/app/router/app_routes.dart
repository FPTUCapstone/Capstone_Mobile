abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/auth/login';
  static const travelerRegistration = '/auth/register/traveler';
  static const operatorRegistration = '/auth/register/operator';
  static const traveler = '/traveler';
  static const operator = '/operator';

  static const authPrefix = '/auth';
  static const travelerPrefix = '/traveler';
  static const operatorPrefix = '/operator';
}

abstract final class AppRouteNames {
  static const splash = 'splash';
  static const login = 'login';
  static const travelerRegistration = 'traveler-registration';
  static const operatorRegistration = 'operator-registration';
  static const traveler = 'traveler';
  static const operator = 'operator';
}
