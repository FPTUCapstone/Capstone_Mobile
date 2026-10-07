/// Canonical commercial service categories supported by TripMate (`BR-87`).
///
/// Report 3 SRS `BR-87`:
/// "TripMate supports exactly three commercial service categories, namely
/// Hotel, Vehicle Rental and Restaurant; a point of interest of any other
/// category never exposes a commercial booking action."
enum CommercialServiceCategory {
  hotel(
    canonicalName: 'Hotel',
    vietnameseLabel: 'Khách sạn (Hotel)',
    specificSectionTitle: 'Room Types',
    unitLabel: 'rooms',
  ),
  vehicleRental(
    canonicalName: 'Vehicle Rental',
    vietnameseLabel: 'Thuê xe (Vehicle Rental)',
    specificSectionTitle: 'Vehicle Types',
    unitLabel: 'vehicles',
  ),
  restaurant(
    canonicalName: 'Restaurant',
    vietnameseLabel: 'Nhà hàng (Restaurant)',
    specificSectionTitle: 'Menu Highlights & Table Capacity',
    unitLabel: 'tables',
  );

  const CommercialServiceCategory({
    required this.canonicalName,
    required this.vietnameseLabel,
    required this.specificSectionTitle,
    required this.unitLabel,
  });

  final String canonicalName;
  final String vietnameseLabel;
  final String specificSectionTitle;
  final String unitLabel;

  /// Resolves [rawCategory] strictly against the three canonical commercial
  /// categories (`Hotel`, `Vehicle Rental`, `Restaurant`) per `BR-87`.
  ///
  /// Returns `null` for any other POI category so non-commercial POIs never
  /// expose a commercial booking action.
  static CommercialServiceCategory? tryFromCategoryName(String? rawCategory) {
    if (rawCategory == null) return null;
    final normalized = rawCategory.trim().toLowerCase();
    return switch (normalized) {
      'hotel' => CommercialServiceCategory.hotel,
      'vehicle rental' => CommercialServiceCategory.vehicleRental,
      'restaurant' => CommercialServiceCategory.restaurant,
      _ => null,
    };
  }

  /// Returns `true` iff [rawCategory] is one of the three canonical commercial
  /// service categories (`BR-87`).
  static bool isCommercialCategory(String? rawCategory) =>
      tryFromCategoryName(rawCategory) != null;
}
