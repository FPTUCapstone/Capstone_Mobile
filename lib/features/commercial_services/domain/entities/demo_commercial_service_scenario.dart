/// Deterministic Demo scenarios for UC-30 (`View Commercial Service`) in Debug
/// Demo mode (`kDebugMode && ?demo=true`).
enum DemoCommercialServiceScenario {
  availableHotel(poiId: 901, label: 'Available Hotel'),
  availableVehicleRental(poiId: 902, label: 'Available Vehicle Rental'),
  availableRestaurant(poiId: 903, label: 'Available Restaurant'),
  inactivePoi(poiId: 904, label: 'Inactive POI'),
  unsupportedCategory(poiId: 905, label: 'Unsupported Category (No Book CTA)'),
  availabilityUnavailable(
    poiId: 906,
    label: 'Availability Missing (Book Disabled)',
  ),
  closedForBooking(poiId: 907, label: 'Closed for Booking'),
  systemFailure(poiId: 908, label: 'System Failure');

  const DemoCommercialServiceScenario({
    required this.poiId,
    required this.label,
  });

  final int poiId;
  final String label;

  static const String defaultIntendedDateIso = '2026-10-15';
  static const String unavailableDemoDateIso = '2026-10-20';
  static const String unavailableDemoTimeSlot = '23:30';

  static DemoCommercialServiceScenario fromPoiId(int poiId) {
    for (final scenario in DemoCommercialServiceScenario.values) {
      if (scenario.poiId == poiId) return scenario;
    }
    return DemoCommercialServiceScenario.availableHotel;
  }
}
