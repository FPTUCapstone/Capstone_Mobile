import 'package:trip_mate_mobile/features/tour_discovery/domain/entities/tour_discovery_item.dart';

/// Test fixtures for Tour Discovery widget and motion tests.
///
/// Strictly isolated to test and development environments; never referenced
/// by production runtime code.
abstract final class TourDiscoveryTestFixtures {
  static const List<TourDiscoveryItem> sampleTours = [
    TourDiscoveryItem(
      id: 'hue',
      title: 'Khám phá Cố đô Huế & Ca Huế sông Hương',
      destinations: 'Huế · Sông Hương',
      operatorName: 'Huế Heritage Travel',
      durationDays: 1,
      priceVnd: 850000,
      rating: 4.9,
      imageUrl: 'assets/images/destinations/hue_ngo_mon.jpg',
      isCuratedAsset: true,
      remainingSlots: 8,
    ),
    TourDiscoveryItem(
      id: 'bana',
      title: 'Bà Nà Hills & Cầu Vàng trọn gói',
      destinations: 'Đà Nẵng · Bà Nà Hills',
      operatorName: 'Danang Explorer',
      durationDays: 1,
      priceVnd: 1250000,
      rating: 4.8,
      imageUrl: 'assets/images/destinations/bana_golden_bridge.jpg',
      isCuratedAsset: true,
      remainingSlots: 12,
    ),
    TourDiscoveryItem(
      id: 'hoian',
      title: 'Hội An phố cổ & Rừng dừa Bảy Mẫu',
      destinations: 'Hội An · Quảng Nam',
      operatorName: 'Hội An Eco Tours',
      durationDays: 1,
      priceVnd: 650000,
      rating: 4.9,
      imageUrl: 'assets/images/destinations/hoian_ancient_town.jpg',
      isCuratedAsset: true,
      remainingSlots: 5,
    ),
  ];
}
