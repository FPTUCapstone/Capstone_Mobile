import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

final class PagedTourResult extends Equatable {
  const PagedTourResult({
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.items,
  });

  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final List<TourSummary> items;

  @override
  List<Object?> get props => [page, pageSize, totalCount, totalPages, items];
}
