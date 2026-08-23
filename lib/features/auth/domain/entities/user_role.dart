enum UserRole {
  traveler,
  tourOperator;

  String get label => switch (this) {
    UserRole.traveler => 'Traveler',
    UserRole.tourOperator => 'Tour Operator',
  };
}
