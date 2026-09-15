import 'package:trip_mate_mobile/features/traveler/data/models/selectable_poi_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi.dart';

final class SelectablePoiSearchResultModel {
  const SelectablePoiSearchResultModel(this.items);

  factory SelectablePoiSearchResultModel.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('Invalid selectable POI search response.');
    }

    return SelectablePoiSearchResultModel(
      items
          .map(
            (item) => SelectablePoiModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ).toEntity(),
          )
          .toList(growable: false),
    );
  }

  final List<SelectablePoi> items;
}
