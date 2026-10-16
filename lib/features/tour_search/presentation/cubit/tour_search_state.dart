import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_category.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_search_query.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

enum TourSearchStatus { initial, loading, success, failure }

final class TourSearchState extends Equatable {
  const TourSearchState({
    this.status = TourSearchStatus.initial,
    this.items = const [],
    this.query = const TourSearchQuery(),
    this.page = 0,
    this.totalCount = 0,
    this.totalPages = 0,
    this.isLoadingMore = false,
    this.failure,
    this.validationFailure,
    this.isRefreshing = false,
    this.categories = const [],
    this.categoriesLoading = false,
    this.categoriesFailure,
  });

  static const _unset = Object();

  final TourSearchStatus status;
  final List<TourSummary> items;
  final TourSearchQuery query;
  final int page;
  final int totalCount;
  final int totalPages;
  final bool isLoadingMore;
  final Failure? failure;
  final ValidationFailure? validationFailure;
  final bool isRefreshing;
  final List<TourCategory> categories;
  final bool categoriesLoading;
  final Failure? categoriesFailure;

  bool get canLoadMore => !isRefreshing && page < totalPages;

  TourSearchState copyWith({
    TourSearchStatus? status,
    List<TourSummary>? items,
    TourSearchQuery? query,
    int? page,
    int? totalCount,
    int? totalPages,
    bool? isLoadingMore,
    Object? failure = _unset,
    Object? validationFailure = _unset,
    bool? isRefreshing,
    List<TourCategory>? categories,
    bool? categoriesLoading,
    Object? categoriesFailure = _unset,
  }) {
    return TourSearchState(
      status: status ?? this.status,
      items: items ?? this.items,
      query: query ?? this.query,
      page: page ?? this.page,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      categories: categories ?? this.categories,
      categoriesLoading: categoriesLoading ?? this.categoriesLoading,
      categoriesFailure: identical(categoriesFailure, _unset)
          ? this.categoriesFailure
          : categoriesFailure as Failure?,
      failure: identical(failure, _unset) ? this.failure : failure as Failure?,
      validationFailure: identical(validationFailure, _unset)
          ? this.validationFailure
          : validationFailure as ValidationFailure?,
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
    failure,
    validationFailure,
    isRefreshing,
    categories,
    categoriesLoading,
    categoriesFailure,
  ];
}
