import 'package:equatable/equatable.dart';

final class PoiSummary extends Equatable {
  const PoiSummary({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.latitude,
    required this.longitude,
    required this.indoorOutdoor,
    required this.averageVisitDurationMinutes,
    required this.hasShelter,
    required this.reviewCount,
    required this.isOpenNow,
    this.address,
    this.averageRating,
    this.thumbnailUrl,
    this.distanceKm,
  });

  final int id;
  final String name;
  final int categoryId;
  final String categoryName;
  final double latitude;
  final double longitude;
  final String? address;
  final String indoorOutdoor;
  final int averageVisitDurationMinutes;
  final bool hasShelter;
  final double? averageRating;
  final int reviewCount;
  final String? thumbnailUrl;
  final double? distanceKm;
  final bool isOpenNow;

  @override
  List<Object?> get props => [
    id,
    name,
    categoryId,
    categoryName,
    latitude,
    longitude,
    address,
    indoorOutdoor,
    averageVisitDurationMinutes,
    hasShelter,
    averageRating,
    reviewCount,
    thumbnailUrl,
    distanceKm,
    isOpenNow,
  ];
}
