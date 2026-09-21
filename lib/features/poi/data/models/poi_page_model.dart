import 'package:trip_mate_mobile/features/poi/domain/entities/paged_poi_result.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';

final class PoiPageModel {
  const PoiPageModel({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.items,
  });

  factory PoiPageModel.fromJson(Map<String, Object?> json) {
    return PoiPageModel(
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'pageSize'),
      totalCount: _requiredInt(json, 'totalCount'),
      totalPages: _requiredInt(json, 'totalPages'),
      items: _objectList(json, 'items').map(PoiSummaryModel.fromJson).toList(),
    );
  }

  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final List<PoiSummaryModel> items;

  PagedPoiResult toEntity() => PagedPoiResult(
    page: page,
    pageSize: pageSize,
    totalCount: totalCount,
    totalPages: totalPages,
    items: items.map((item) => item.toEntity()).toList(growable: false),
  );
}

final class PoiSummaryModel {
  const PoiSummaryModel({
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

  factory PoiSummaryModel.fromJson(Map<String, Object?> json) {
    return PoiSummaryModel(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      categoryId: _requiredInt(json, 'categoryId'),
      categoryName: _requiredString(json, 'categoryName'),
      latitude: _requiredDouble(json, 'latitude'),
      longitude: _requiredDouble(json, 'longitude'),
      address: _nullableString(json['address']),
      indoorOutdoor: _requiredString(json, 'indoorOutdoor'),
      averageVisitDurationMinutes: _requiredInt(
        json,
        'averageVisitDurationMinutes',
      ),
      hasShelter: _requiredBool(json, 'hasShelter'),
      averageRating: _nullableDouble(json['averageRating']),
      reviewCount: _requiredInt(json, 'reviewCount'),
      thumbnailUrl: _nullableString(json['thumbnailUrl']),
      distanceKm: _nullableDouble(json['distanceKm']),
      isOpenNow: _requiredBool(json, 'isOpenNow'),
    );
  }

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

  PoiSummary toEntity() => PoiSummary(
    id: id,
    name: name,
    categoryId: categoryId,
    categoryName: categoryName,
    latitude: latitude,
    longitude: longitude,
    address: address,
    indoorOutdoor: indoorOutdoor,
    averageVisitDurationMinutes: averageVisitDurationMinutes,
    hasShelter: hasShelter,
    averageRating: averageRating,
    reviewCount: reviewCount,
    thumbnailUrl: thumbnailUrl,
    distanceKm: distanceKm,
    isOpenNow: isOpenNow,
  );
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw FormatException('$key must be a number.');
}

double _requiredDouble(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('$key must be a number.');
}

double? _nullableDouble(Object? value) => switch (value) {
  final num number => number.toDouble(),
  _ => null,
};

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('$key must be a string.');
}

String? _nullableString(Object? value) => value is String ? value : null;

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('$key must be a boolean.');
}

List<Map<String, Object?>> _objectList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be a list.');
  }
  return value
      .map(
        (item) => item is Map<String, Object?>
            ? item
            : Map<String, Object?>.from(item! as Map),
      )
      .toList(growable: false);
}
