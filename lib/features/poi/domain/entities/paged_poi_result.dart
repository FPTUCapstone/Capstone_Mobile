import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_summary.dart';

final class PagedPoiResult extends Equatable {
  const PagedPoiResult({
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
  final List<PoiSummary> items;

  @override
  List<Object?> get props => [page, pageSize, totalCount, totalPages, items];
}
