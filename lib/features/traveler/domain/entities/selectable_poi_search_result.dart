import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi.dart';

final class SelectablePoiSearchResult extends Equatable {
  const SelectablePoiSearchResult({
    required this.items,
    required this.totalCount,
  });

  final List<SelectablePoi> items;
  final int totalCount;

  @override
  List<Object?> get props => [items, totalCount];
}
