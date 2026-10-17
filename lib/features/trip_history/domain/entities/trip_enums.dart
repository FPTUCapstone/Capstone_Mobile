enum TripType {
  tour,
  commercialService,
  itinerary;

  String get label => switch (this) {
    TripType.tour => 'Tour',
    TripType.commercialService => 'Commercial Service',
    TripType.itinerary => 'Itinerary',
  };
}

enum TripStatus {
  upcoming,
  completed,
  cancelled;

  String get label => switch (this) {
    TripStatus.upcoming => 'Upcoming',
    TripStatus.completed => 'Completed',
    TripStatus.cancelled => 'Cancelled',
  };
}
