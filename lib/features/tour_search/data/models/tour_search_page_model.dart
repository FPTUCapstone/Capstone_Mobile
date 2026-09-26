import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/paged_tour_result.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

final class TourSearchPageModel {
  const TourSearchPageModel({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.items,
  });

  factory TourSearchPageModel.fromJson(Map<String, Object?> json) {
    return TourSearchPageModel(
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'pageSize'),
      totalCount: _requiredInt(json, 'totalCount'),
      totalPages: _requiredInt(json, 'totalPages'),
      items: _objectList(json, 'items')
          .map((item) => TourSearchItemModel.fromJson(item))
          .toList(growable: false),
    );
  }

  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final List<TourSearchItemModel> items;

  PagedTourResult toEntity() => PagedTourResult(
    page: page,
    pageSize: pageSize,
    totalCount: totalCount,
    totalPages: totalPages,
    items: items.map((item) => item.toEntity()).toList(growable: false),
  );
}

final class TourSearchItemModel {
  const TourSearchItemModel({
    required this.tourId,
    required this.title,
    required this.destinations,
    required this.operatorName,
    required this.durationDays,
    required this.basePrice,
    required this.currency,
    required this.representativeScheduleId,
    required this.departureAtUtc,
    required this.availabilityStatus,
    required this.remainingSlots,
  });

  factory TourSearchItemModel.fromJson(Map<String, Object?> json) {
    final departureStr = _nullableString(json['departureAtUtc']);
    return TourSearchItemModel(
      tourId: _requiredString(json, 'tourId'),
      title: _requiredString(json, 'title'),
      destinations: _stringList(json, 'destinations'),
      operatorName: _requiredString(json, 'operatorName'),
      durationDays: _requiredInt(json, 'durationDays'),
      basePrice: _requiredInt(json, 'basePrice'),
      currency: _requiredString(json, 'currency'),
      representativeScheduleId: _nullableString(
        json['representativeScheduleId'],
      ),
      // The public Tour Search API emits this field from UTC DateTime values.
      // Normalize offset-bearing timestamps here so presentation always receives UTC.
      departureAtUtc: departureStr != null
          ? DateTime.tryParse(departureStr)?.toUtc()
          : null,
      availabilityStatus: _requiredString(json, 'availabilityStatus'),
      remainingSlots: _nullableInt(json['remainingSlots']),
    );
  }

  final String tourId;
  final String title;
  final List<String> destinations;
  final String operatorName;
  final int durationDays;
  final int basePrice;
  final String currency;
  final String? representativeScheduleId;
  final DateTime? departureAtUtc;
  final String availabilityStatus;
  final int? remainingSlots;

  TourSummary toEntity() => TourSummary(
    tourId: tourId,
    title: title,
    destinations: destinations,
    operatorName: operatorName,
    durationDays: durationDays,
    basePrice: basePrice,
    currency: currency,
    representativeScheduleId: representativeScheduleId,
    departureAtUtc: departureAtUtc,
    availabilityStatus: AvailabilityStatus.fromString(availabilityStatus),
    remainingSlots: remainingSlots,
  );
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is num) return value.toInt();
  throw FormatException('Missing or invalid $key.');
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Missing or invalid $key.');
}

String? _nullableString(Object? value) {
  if (value is String) return value;
  return null;
}

int? _nullableInt(Object? value) => switch (value) {
  final num number => number.toInt(),
  _ => null,
};

List<Map<String, Object?>> _objectList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) return [];
  return value
      .whereType<Map<Object?, Object?>>()
      .map((item) => item.cast<String, Object?>())
      .toList(growable: false);
}

List<String> _stringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be a list.');
  }
  return value.whereType<String>().toList(growable: false);
}
