import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';

enum PoiSort {
  name('name'),
  distance('distance'),
  rating('rating');

  const PoiSort(this.apiValue);
  final String apiValue;
}

final class PoiQuery extends Equatable {
  const PoiQuery({
    this.search,
    this.categoryId,
    this.originLatitude,
    this.originLongitude,
    this.maxDistanceKm,
    this.openNow = false,
    this.sort = PoiSort.name,
    this.page = 1,
    this.pageSize = 20,
  });

  static const _unset = Object();

  final String? search;
  final int? categoryId;
  final double? originLatitude;
  final double? originLongitude;
  final double? maxDistanceKm;
  final bool openNow;
  final PoiSort sort;
  final int page;
  final int pageSize;

  bool get hasOrigin => originLatitude != null && originLongitude != null;

  Map<String, Object> toQueryParameters() {
    final normalizedSearch = search?.trim();
    if (normalizedSearch != null && normalizedSearch.length > 200) {
      throw const ValidationFailure(
        'Từ khóa tìm kiếm không được vượt quá 200 ký tự.',
        fieldErrors: {
          'search': ['Từ khóa tìm kiếm không được vượt quá 200 ký tự.'],
        },
      );
    }
    final safeCategoryId = categoryId != null && categoryId! > 0
        ? categoryId
        : null;
    final safeDistance =
        hasOrigin && maxDistanceKm != null && maxDistanceKm! > 0
        ? maxDistanceKm
        : null;
    final safeSort = sort == PoiSort.distance && !hasOrigin
        ? PoiSort.name
        : sort;

    final parameters = <String, Object>{
      if (normalizedSearch != null && normalizedSearch.isNotEmpty)
        'search': normalizedSearch,
      if (hasOrigin) ...{
        'originLatitude': originLatitude!,
        'originLongitude': originLongitude!,
      },
      if (openNow) 'openNow': true,
      'sort': safeSort.apiValue,
      'page': page,
      'pageSize': pageSize,
    };
    if (safeCategoryId != null) {
      parameters['categoryId'] = safeCategoryId;
    }
    if (safeDistance != null) {
      parameters['maxDistanceKm'] = safeDistance;
    }
    return parameters;
  }

  PoiQuery copyWith({
    Object? search = _unset,
    Object? categoryId = _unset,
    Object? originLatitude = _unset,
    Object? originLongitude = _unset,
    Object? maxDistanceKm = _unset,
    bool? openNow,
    PoiSort? sort,
    int? page,
    int? pageSize,
  }) {
    return PoiQuery(
      search: identical(search, _unset) ? this.search : search as String?,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as int?,
      originLatitude: identical(originLatitude, _unset)
          ? this.originLatitude
          : originLatitude as double?,
      originLongitude: identical(originLongitude, _unset)
          ? this.originLongitude
          : originLongitude as double?,
      maxDistanceKm: identical(maxDistanceKm, _unset)
          ? this.maxDistanceKm
          : maxDistanceKm as double?,
      openNow: openNow ?? this.openNow,
      sort: sort ?? this.sort,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  List<Object?> get props => [
    search,
    categoryId,
    originLatitude,
    originLongitude,
    maxDistanceKm,
    openNow,
    sort,
    page,
    pageSize,
  ];
}
