import 'package:equatable/equatable.dart';

final class PoiDetail extends Equatable {
  const PoiDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.categoryId,
    required this.categoryName,
    required this.latitude,
    required this.longitude,
    required this.indoorOutdoor,
    required this.averageVisitDurationMinutes,
    required this.hasShelter,
    required this.reviewCount,
    required this.isOpenNow,
    required this.openingHours,
    required this.photos,
    required this.tags,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.address,
    this.scenicScore,
    this.photoRating,
    this.averageRating,
  });

  final int id;
  final String name;
  final String? description;
  final String status;
  final int categoryId;
  final String categoryName;
  final double latitude;
  final double longitude;
  final String? address;
  final String indoorOutdoor;
  final int averageVisitDurationMinutes;
  final bool hasShelter;
  final double? scenicScore;
  final double? photoRating;
  final double? averageRating;
  final int reviewCount;
  final bool isOpenNow;
  final List<PoiOpeningHour> openingHours;
  final List<PoiPhoto> photos;
  final List<PoiTag> tags;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    status,
    categoryId,
    categoryName,
    latitude,
    longitude,
    address,
    indoorOutdoor,
    averageVisitDurationMinutes,
    hasShelter,
    scenicScore,
    photoRating,
    averageRating,
    reviewCount,
    isOpenNow,
    openingHours,
    photos,
    tags,
    createdAtUtc,
    updatedAtUtc,
  ];
}

final class PoiOpeningHour extends Equatable {
  const PoiOpeningHour({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    required this.isClosed,
  });

  final int dayOfWeek;
  final String? openTime;
  final String? closeTime;
  final bool isClosed;

  @override
  List<Object?> get props => [dayOfWeek, openTime, closeTime, isClosed];
}

final class PoiPhoto extends Equatable {
  const PoiPhoto({
    required this.id,
    required this.url,
    required this.sortOrder,
    this.caption,
  });

  final int id;
  final String url;
  final String? caption;
  final int sortOrder;

  @override
  List<Object?> get props => [id, url, caption, sortOrder];
}

final class PoiTag extends Equatable {
  const PoiTag({required this.id, required this.name});

  final int id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}
