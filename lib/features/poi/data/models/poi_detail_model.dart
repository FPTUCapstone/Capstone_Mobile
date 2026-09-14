import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';

final class PoiDetailModel {
  const PoiDetailModel({
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

  factory PoiDetailModel.fromJson(Map<String, Object?> json) {
    return PoiDetailModel(
      id: _int(json, 'id'),
      name: _string(json, 'name'),
      description: _string(json, 'description'),
      status: _string(json, 'status'),
      categoryId: _int(json, 'categoryId'),
      categoryName: _string(json, 'categoryName'),
      latitude: _double(json, 'latitude'),
      longitude: _double(json, 'longitude'),
      address: _nullableString(json['address']),
      indoorOutdoor: _string(json, 'indoorOutdoor'),
      averageVisitDurationMinutes: _int(json, 'averageVisitDurationMinutes'),
      hasShelter: _bool(json, 'hasShelter'),
      scenicScore: _nullableDouble(json['scenicScore']),
      photoRating: _nullableDouble(json['photoRating']),
      averageRating: _nullableDouble(json['averageRating']),
      reviewCount: _int(json, 'reviewCount'),
      isOpenNow: _bool(json, 'isOpenNow'),
      openingHours: _maps(
        json,
        'openingHours',
      ).map(PoiOpeningHourModel.fromJson).toList(),
      photos: _maps(json, 'photos').map(PoiPhotoModel.fromJson).toList(),
      tags: _maps(json, 'tags').map(PoiTagModel.fromJson).toList(),
      createdAtUtc: DateTime.parse(_string(json, 'createdAtUtc')).toUtc(),
      updatedAtUtc: DateTime.parse(_string(json, 'updatedAtUtc')).toUtc(),
    );
  }

  final int id;
  final String name;
  final String description;
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
  final List<PoiOpeningHourModel> openingHours;
  final List<PoiPhotoModel> photos;
  final List<PoiTagModel> tags;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  PoiDetail toEntity() => PoiDetail(
    id: id,
    name: name,
    description: description,
    status: status,
    categoryId: categoryId,
    categoryName: categoryName,
    latitude: latitude,
    longitude: longitude,
    address: address,
    indoorOutdoor: indoorOutdoor,
    averageVisitDurationMinutes: averageVisitDurationMinutes,
    hasShelter: hasShelter,
    scenicScore: scenicScore,
    photoRating: photoRating,
    averageRating: averageRating,
    reviewCount: reviewCount,
    isOpenNow: isOpenNow,
    openingHours: openingHours.map((item) => item.toEntity()).toList(),
    photos: photos.map((item) => item.toEntity()).toList(),
    tags: tags.map((item) => item.toEntity()).toList(),
    createdAtUtc: createdAtUtc,
    updatedAtUtc: updatedAtUtc,
  );
}

final class PoiOpeningHourModel {
  const PoiOpeningHourModel({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    required this.isClosed,
  });

  factory PoiOpeningHourModel.fromJson(Map<String, Object?> json) =>
      PoiOpeningHourModel(
        dayOfWeek: _int(json, 'dayOfWeek'),
        openTime: _nullableString(json['openTime']),
        closeTime: _nullableString(json['closeTime']),
        isClosed: _bool(json, 'isClosed'),
      );

  final int dayOfWeek;
  final String? openTime;
  final String? closeTime;
  final bool isClosed;

  PoiOpeningHour toEntity() => PoiOpeningHour(
    dayOfWeek: dayOfWeek,
    openTime: openTime,
    closeTime: closeTime,
    isClosed: isClosed,
  );
}

final class PoiPhotoModel {
  const PoiPhotoModel({
    required this.id,
    required this.url,
    required this.sortOrder,
    this.caption,
  });

  factory PoiPhotoModel.fromJson(Map<String, Object?> json) => PoiPhotoModel(
    id: _int(json, 'id'),
    url: _string(json, 'url'),
    caption: _nullableString(json['caption']),
    sortOrder: _int(json, 'sortOrder'),
  );

  final int id;
  final String url;
  final String? caption;
  final int sortOrder;

  PoiPhoto toEntity() =>
      PoiPhoto(id: id, url: url, caption: caption, sortOrder: sortOrder);
}

final class PoiTagModel {
  const PoiTagModel({required this.id, required this.name});

  factory PoiTagModel.fromJson(Map<String, Object?> json) =>
      PoiTagModel(id: _int(json, 'id'), name: _string(json, 'name'));

  final int id;
  final String name;

  PoiTag toEntity() => PoiTag(id: id, name: name);
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw FormatException('$key must be a number.');
}

double _double(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num) return value.toDouble();
  throw FormatException('$key must be a number.');
}

double? _nullableDouble(Object? value) => switch (value) {
  final num number => number.toDouble(),
  _ => null,
};

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('$key must be a string.');
}

String? _nullableString(Object? value) => value is String ? value : null;

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('$key must be a boolean.');
}

List<Map<String, Object?>> _maps(Map<String, Object?> json, String key) {
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
