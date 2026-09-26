import 'package:trip_mate_mobile/features/traveler/data/models/selectable_poi_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi.dart';

final class SelectablePoiSearchResultModel {
  const SelectablePoiSearchResultModel({
    required this.items,
    required this.totalCount,
  });

  factory SelectablePoiSearchResultModel.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('Invalid selectable POI search response.');
    }
    final totalCount = json['totalCount'];
    if (totalCount is! int || totalCount < 0) {
      throw const FormatException('Invalid selectable POI search response.');
    }

    return SelectablePoiSearchResultModel(
      items: items
          .map(
            (item) => SelectablePoiModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ).toEntity(),
          )
          .toList(growable: false),
      totalCount: totalCount,
    );
  }

  final List<SelectablePoi> items;
  final int totalCount;
}
