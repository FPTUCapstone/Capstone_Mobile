import 'package:trip_mate_mobile/features/traveler/domain/entities/selectable_poi.dart';

final class SelectablePoiModel {
  const SelectablePoiModel(this._json);

  factory SelectablePoiModel.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! int ||
        json['name'] is! String ||
        json['latitude'] is! num ||
        json['longitude'] is! num ||
        json['averageVisitDurationMinutes'] is! int ||
        json['openingHoursKnown'] is! bool ||
        json['hasShelter'] is! bool) {
      throw const FormatException('Invalid selectable POI response.');
    }
    return SelectablePoiModel(json);
  }

  final Map<String, dynamic> _json;

  SelectablePoi toEntity() => SelectablePoi(
    id: _json['id'] as int,
    name: (_json['name'] as String).trim(),
    address: _json['address'] as String?,
    latitude: (_json['latitude'] as num).toDouble(),
    longitude: (_json['longitude'] as num).toDouble(),
    averageVisitDurationMinutes: _json['averageVisitDurationMinutes'] as int,
    estimatedVisitCost: (_json['estimatedVisitCost'] as num?)?.toDouble(),
    openingHoursKnown: _json['openingHoursKnown'] as bool,
    hasShelter: _json['hasShelter'] as bool,
    categoryName: _json['categoryName'] as String?,
  );
}
