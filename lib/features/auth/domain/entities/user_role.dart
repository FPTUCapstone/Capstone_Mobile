enum UserRole {
  traveler,
  tourOperator;

  String get label => switch (this) {
    UserRole.traveler => 'Du khách',
    UserRole.tourOperator => 'Nhà điều hành tour',
  };
}
