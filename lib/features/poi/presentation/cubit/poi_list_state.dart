import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_query.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';

enum PoiListStatus { initial, loading, success, failure }

final class PoiListState extends Equatable {
  const PoiListState({
    this.status = PoiListStatus.initial,
    this.items = const [],
    this.query = const PoiQuery(),
    this.page = 0,
    this.totalCount = 0,
    this.totalPages = 0,
    this.isLoadingMore = false,
    this.isMapView = false,
    this.isLocating = false,
    this.failure,
    this.validationFailure,
    this.locationMessage,
    this.selectedPoiId,
  });

  static const _unset = Object();

  final PoiListStatus status;
  final List<PoiSummary> items;
  final PoiQuery query;
  final int page;
  final int totalCount;
  final int totalPages;
  final bool isLoadingMore;
  final bool isMapView;
  final bool isLocating;
  final Failure? failure;
  final ValidationFailure? validationFailure;
  final String? locationMessage;
  final int? selectedPoiId;

  bool get canLoadMore => page < totalPages;
  PoiSummary? get selectedPoi {
    for (final item in items) {
      if (item.id == selectedPoiId) return item;
    }
    return items.isEmpty ? null : items.first;
  }

  PoiListState copyWith({
    PoiListStatus? status,
    List<PoiSummary>? items,
    PoiQuery? query,
    int? page,
    int? totalCount,
    int? totalPages,
    bool? isLoadingMore,
    bool? isMapView,
    bool? isLocating,
    Object? failure = _unset,
    Object? validationFailure = _unset,
    Object? locationMessage = _unset,
    Object? selectedPoiId = _unset,
  }) {
    return PoiListState(
      status: status ?? this.status,
      items: items ?? this.items,
      query: query ?? this.query,
      page: page ?? this.page,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isMapView: isMapView ?? this.isMapView,
      isLocating: isLocating ?? this.isLocating,
      failure: identical(failure, _unset) ? this.failure : failure as Failure?,
      validationFailure: identical(validationFailure, _unset)
          ? this.validationFailure
          : validationFailure as ValidationFailure?,
      locationMessage: identical(locationMessage, _unset)
          ? this.locationMessage
          : locationMessage as String?,
      selectedPoiId: identical(selectedPoiId, _unset)
          ? this.selectedPoiId
          : selectedPoiId as int?,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    query,
    page,
    totalCount,
    totalPages,
    isLoadingMore,
    isMapView,
    isLocating,
    failure,
    validationFailure,
    locationMessage,
    selectedPoiId,
  ];
}
