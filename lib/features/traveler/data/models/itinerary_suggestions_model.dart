import 'package:trip_mate_mobile/features/poi/data/models/cost_kind_json.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/json_readers.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';

/// `GET /api/v1/itineraries/{id}/suggestions` response.
final class ItinerarySuggestionsModel {
  const ItinerarySuggestionsModel(this._json);

  factory ItinerarySuggestionsModel.fromJson(Map<String, dynamic> json) {
    if (json['itineraryId'] is! int ||
        json['kind'] is! String ||
        json['searchRadiusKm'] is! num ||
        json['items'] is! List) {
      throw const FormatException('Invalid itinerary suggestions response.');
    }
    return ItinerarySuggestionsModel(json);
  }

  final Map<String, dynamic> _json;

  ItinerarySuggestions toEntity() => ItinerarySuggestions(
    itineraryId: _json['itineraryId'] as int,
    kind: _json['kind'] == 'Replace'
        ? SuggestionKind.replace
        : SuggestionKind.food,
    searchRadiusKm: (_json['searchRadiusKm'] as num).toDouble(),
    items: (_json['items'] as List)
        .map((item) => _item(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false),
  );

  static ItinerarySuggestion _item(Map<String, dynamic> json) {
    final poiId = json['poiId'];
    final name = json['name'];
    if (poiId is! int || name is! String) {
      throw const FormatException('Invalid itinerary suggestion.');
    }
    final arrival = json['estimatedArrival'];
    return ItinerarySuggestion(
      poiId: poiId,
      name: name,
      category: readString(json['category']),
      thumbnailUrl: readString(json['thumbnailUrl']),
      address: readString(json['address']),
      costKind: parseCostKind(json['costKind']),
      estimatedCost: readDouble(json['estimatedCost']),
      distanceFromPreviousMeters: readInt(json['distanceFromPreviousMeters']),
      detourMinutes: readInt(json['detourMinutes']),
      isStraightLine: json['distanceSource'] == 'StraightLine',
      estimatedArrival: arrival is String
          ? DateTime.tryParse(arrival)?.toUtc()
          : null,
      openAtArrival: readBool(json['openAtArrival']),
      closesAt: readString(json['closesAt']),
      fitsItinerary: readBool(json['fitsItinerary']),
      unfitReason: readString(json['unfitReason']),
      unfitPoiId: readInt(json['unfitPoiId']),
      overflowMinutes: readInt(json['overflowMinutes']),
      overflowVnd: readDouble(json['overflowVnd']),
      tripadvisor: tripadvisorRatingFromJson(json['tripadvisor']),
    );
  }
}

TripadvisorRating? tripadvisorRatingFromJson(Object? value) {
  if (value is! Map) return null;
  final locationId = readInt(value['locationId']);
  if (locationId == null) return null;
  return TripadvisorRating(
    locationId: locationId,
    rating: readDouble(value['rating']),
    reviewCount: readInt(value['reviewCount']) ?? 0,
    ratingImageUrl: readString(value['ratingImageUrl']),
    url: readString(value['url']),
    hasRecentReviews: readBool(value['hasRecentReviews']),
  );
}
