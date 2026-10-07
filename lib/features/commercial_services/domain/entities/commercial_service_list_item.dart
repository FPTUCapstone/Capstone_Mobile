import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_capability.dart';
import 'package:trip_mate_mobile/features/commercial_services/domain/entities/commercial_service_category.dart';
import 'package:trip_mate_mobile/features/commercial_services/resources/commercial_service_en.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';

/// Lightweight summary model for Screen #71 (`Commercial Services Search & List`).
///
/// In Production, items are constructed from real `PoiSummary` objects returned
/// by `GET /api/v1/pois` (UC-12). In Demo mode (`kDebugMode && ?demo=true`),
/// items are constructed from deterministic demo fixtures with display-time
/// commercial availability and price ranges.
final class CommercialServiceListItem extends Equatable {
  const CommercialServiceListItem({
    required this.id,
    required this.name,
    required this.categoryName,
    required this.category,
    required this.address,
    required this.rating,
    required this.reviewCount,
    required this.isOpenNow,
    this.thumbnailUrl,
    this.priceRangeLabel,
    this.startingPriceVnd,
    this.availabilityStatusLabel,
    this.isAvailableForDate,
    this.isOpenForBooking = true,
    this.isCommercialDataBackedByServer = false,
  });

  /// Factory constructing a list item from a real Backend [PoiSummary].
  ///
  /// Commercial inventory and rate filters are not exposed by the base POI
  /// endpoint, so pricing and availability are marked as pending server integration.
  factory CommercialServiceListItem.fromPoiSummary(PoiSummary poi) {
    final commercialCategory = CommercialServiceCategory.tryFromCategoryName(
      poi.categoryName,
    );
    return CommercialServiceListItem(
      id: poi.id,
      name: poi.name,
      categoryName: poi.categoryName,
      category: commercialCategory,
      address: poi.address,
      rating: poi.averageRating,
      reviewCount: poi.reviewCount,
      isOpenNow: poi.isOpenNow,
      thumbnailUrl: poi.thumbnailUrl,
      priceRangeLabel: CommercialServiceEn.search.pendingServerIntegration,
      availabilityStatusLabel:
          CommercialServiceEn.search.pendingServerIntegration,
      isOpenForBooking: true,
      isCommercialDataBackedByServer: false,
    );
  }

  /// Factory constructing a list item from a demo [CommercialServiceDetailComposite].
  factory CommercialServiceListItem.fromComposite(
    CommercialServiceDetailComposite composite,
  ) {
    final minPrice = composite.options.isNotEmpty
        ? composite.options
              .map((o) => o.unitPriceVnd)
              .reduce((a, b) => a < b ? a : b)
        : null;

    final availabilityLabel = switch (composite.availability) {
      null => CommercialServiceEn.search.availabilityMissing,
      final a when !a.isRetrieved =>
        CommercialServiceEn.search.availabilityMissing,
      final a when a.isAvailableForDate => CommercialServiceEn.search.available,
      _ => CommercialServiceEn.search.fullyBooked,
    };

    return CommercialServiceListItem(
      id: composite.poi.id,
      name: composite.poi.name,
      categoryName: composite.poi.categoryName,
      category: composite.commercialCategory,
      address: composite.poi.address,
      rating: composite.poi.averageRating,
      reviewCount: composite.poi.reviewCount,
      isOpenNow: composite.poi.isOpenNow,
      thumbnailUrl: composite.poi.photos.isNotEmpty
          ? composite.poi.photos.first.url
          : null,
      priceRangeLabel: composite.priceRangeLabel,
      startingPriceVnd: minPrice,
      availabilityStatusLabel: availabilityLabel,
      isAvailableForDate: composite.availability?.isAvailableForDate,
      isOpenForBooking: composite.isOpenForBooking ?? true,
      isCommercialDataBackedByServer: true,
    );
  }

  final int id;
  final String name;
  final String categoryName;
  final CommercialServiceCategory? category;
  final String? address;
  final double? rating;
  final int reviewCount;
  final bool isOpenNow;
  final String? thumbnailUrl;
  final String? priceRangeLabel;
  final int? startingPriceVnd;
  final String? availabilityStatusLabel;
  final bool? isAvailableForDate;
  final bool isOpenForBooking;
  final bool isCommercialDataBackedByServer;

  /// Returns `true` iff this item matches one of the 3 canonical categories (`BR-87`).
  bool get isCommercial => category != null;

  @override
  List<Object?> get props => [
    id,
    name,
    categoryName,
    category,
    address,
    rating,
    reviewCount,
    isOpenNow,
    thumbnailUrl,
    priceRangeLabel,
    startingPriceVnd,
    availabilityStatusLabel,
    isAvailableForDate,
    isOpenForBooking,
    isCommercialDataBackedByServer,
  ];
}
