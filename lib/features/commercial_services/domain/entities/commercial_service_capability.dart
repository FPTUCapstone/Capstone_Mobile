import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';

/// Represents a bookable commercial service option for a commercial POI:
/// - `Hotel`: room type
/// - `Vehicle Rental`: vehicle type
/// - `Restaurant`: table/dining option
final class CommercialServiceOption extends Equatable {
  const CommercialServiceOption({
    required this.optionId,
    required this.name,
    required this.description,
    required this.unitPriceVnd,
    required this.priceUnitLabel,
    required this.availableQuantity,
    this.capacityLabel,
  });

  final String optionId;
  final String name;
  final String description;
  final int unitPriceVnd;
  final String priceUnitLabel;
  final int availableQuantity;
  final String? capacityLabel;

  @override
  List<Object?> get props => [
    optionId,
    name,
    description,
    unitPriceVnd,
    priceUnitLabel,
    availableQuantity,
    capacityLabel,
  ];
}

/// Restaurant-specific details required by UC-30 (`menu highlights` and
/// `table capacity`).
final class RestaurantSpecificInfo extends Equatable {
  const RestaurantSpecificInfo({
    required this.menuHighlights,
    required this.totalTableCapacity,
  });

  final List<String> menuHighlights;
  final int totalTableCapacity;

  @override
  List<Object?> get props => [menuHighlights, totalTableCapacity];
}

/// Display-time availability indicator for a commercial service (`BR-55`,
/// `BR-88`).
///
/// Report 3 SRS `BR-55`:
/// "The availability information of a commercial service is retrieved at
/// display time and is not a reservation."
final class CommercialAvailabilityInfo extends Equatable {
  const CommercialAvailabilityInfo({
    required this.intendedDateIso,
    required this.isRetrieved,
    required this.isAvailableForDate,
    required this.totalAvailableUnits,
    required this.availableTimeSlots,
    this.retrievedAtUtc,
  });

  final String intendedDateIso;
  final bool isRetrieved;
  final bool isAvailableForDate;
  final int totalAvailableUnits;
  final List<String> availableTimeSlots;
  final DateTime? retrievedAtUtc;

  @override
  List<Object?> get props => [
    intendedDateIso,
    isRetrieved,
    isAvailableForDate,
    totalAvailableUnits,
    availableTimeSlots,
    retrievedAtUtc,
  ];
}

/// Composes real [PoiDetail] data from UC-12 (`GET /api/v1/pois/{id}`) with
/// commercial service capability fields for UC-30.
///
/// In Production (`isCommercialDataBackedByServer == false`), real POI fields
/// (`name`, `categoryName`, `address`, `coordinates`, `openingHours`, `photos`,
/// `averageRating`, `reviewCount`, `description`, `tags`) are displayed
/// truthfully while commercial options, commercial pricing, contact info, and
/// display-time availability remain explicitly `null` / empty (`pending server
/// integration`) so zero fake commercial data is fabricated.
final class CommercialServiceDetailComposite extends Equatable {
  const CommercialServiceDetailComposite({
    required this.poi,
    required this.commercialCategory,
    required this.isCommercialDataBackedByServer,
    this.contactInfo,
    this.priceRangeLabel,
    this.isOpenForBooking,
    this.options = const [],
    this.restaurantInfo,
    this.availability,
  });

  /// Constructs a Production composite from a real Backend [PoiDetail].
  ///
  /// Because `PoiDetailDto` (`GET /api/v1/pois/{id}`) provides base POI data
  /// (`REAL_BACKEND`) but does not return commercial options, commercial price
  /// ranges, or display-time availability (`NO_BACKEND`), all commercial-only
  /// fields are left unpopulated (`null` / empty) and [canBookService]
  /// evaluates to `false` per `BR-88`.
  factory CommercialServiceDetailComposite.fromProductionPoi(PoiDetail poi) {
    return CommercialServiceDetailComposite(
      poi: poi,
      commercialCategory: CommercialServiceCategory.tryFromCategoryName(
        poi.categoryName,
      ),
      isCommercialDataBackedByServer: false,
    );
  }

  final PoiDetail poi;
  final CommercialServiceCategory? commercialCategory;
  final bool isCommercialDataBackedByServer;
  final String? contactInfo;
  final String? priceRangeLabel;
  final bool? isOpenForBooking;
  final List<CommercialServiceOption> options;
  final RestaurantSpecificInfo? restaurantInfo;
  final CommercialAvailabilityInfo? availability;

  /// `BR-34`: Detailed information is displayed only while the POI has status
  /// `Active`.
  bool get isActivePoi => poi.status.trim().toLowerCase() == 'active';

  /// `BR-87`: Only `Hotel`, `Vehicle Rental`, and `Restaurant` are commercial
  /// service categories.
  bool get isCommercialPoi => commercialCategory != null;

  /// `BR-88`: `Book Service` is enabled only when:
  /// - POI is `Active` (`BR-34`)
  /// - Category is `Hotel`, `Vehicle Rental`, or `Restaurant` (`BR-87`)
  /// - Commercial service is marked open for booking
  /// - Display-time availability for the intended date was retrieved (`BR-55`)
  bool get canBookService =>
      isActivePoi &&
      isCommercialPoi &&
      isCommercialDataBackedByServer &&
      isOpenForBooking == true &&
      availability != null &&
      availability!.isRetrieved &&
      availability!.isAvailableForDate &&
      options.any((option) => option.availableQuantity > 0);

  CommercialServiceDetailComposite copyWith({
    PoiDetail? poi,
    CommercialServiceCategory? commercialCategory,
    bool? isCommercialDataBackedByServer,
    String? contactInfo,
    String? priceRangeLabel,
    bool? isOpenForBooking,
    List<CommercialServiceOption>? options,
    RestaurantSpecificInfo? restaurantInfo,
    CommercialAvailabilityInfo? availability,
    bool clearAvailability = false,
  }) {
    return CommercialServiceDetailComposite(
      poi: poi ?? this.poi,
      commercialCategory: commercialCategory ?? this.commercialCategory,
      isCommercialDataBackedByServer:
          isCommercialDataBackedByServer ?? this.isCommercialDataBackedByServer,
      contactInfo: contactInfo ?? this.contactInfo,
      priceRangeLabel: priceRangeLabel ?? this.priceRangeLabel,
      isOpenForBooking: isOpenForBooking ?? this.isOpenForBooking,
      options: options ?? this.options,
      restaurantInfo: restaurantInfo ?? this.restaurantInfo,
      availability: clearAvailability
          ? null
          : (availability ?? this.availability),
    );
  }

  @override
  List<Object?> get props => [
    poi,
    commercialCategory,
    isCommercialDataBackedByServer,
    contactInfo,
    priceRangeLabel,
    isOpenForBooking,
    options,
    restaurantInfo,
    availability,
  ];
}
