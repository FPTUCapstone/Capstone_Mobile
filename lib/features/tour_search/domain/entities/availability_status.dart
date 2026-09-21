enum AvailabilityStatus {
  available,
  soldOut,
  noUpcomingSchedule,
  unknown;

  static AvailabilityStatus fromString(String value) {
    for (final status in values) {
      if (status.name == value) return status;
    }
    return unknown;
  }
}
