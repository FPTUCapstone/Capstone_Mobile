import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

final class ItineraryDetailModel {
  const ItineraryDetailModel(this._json);

  factory ItineraryDetailModel.fromJson(Map<String, dynamic> json) {
    if (json['itineraryId'] is! int ||
        json['schedulingRequestId'] is! int ||
        json['version'] is! int ||
        json['status'] is! String ||
        json['canManage'] is! bool ||
        json['totalDurationMinutes'] is! int ||
        json['items'] is! List) {
      throw const FormatException('Invalid itinerary detail response.');
    }
    return ItineraryDetailModel(json);
  }

  final Map<String, dynamic> _json;

  ItineraryDetail toEntity() => ItineraryDetail(
    itineraryId: _json['itineraryId'] as int,
    schedulingRequestId: _json['schedulingRequestId'] as int,
    title: _json['title'] as String?,
    version: _json['version'] as int,
    status: _json['status'] as String,
    validFrom: _date(_json['validFrom']),
    validTo: _date(_json['validTo']),
    canManage: _json['canManage'] as bool,
    totalEstimatedCost: (_json['totalEstimatedCost'] as num?)?.toDouble() ?? 0,
    totalDurationMinutes: _json['totalDurationMinutes'] as int,
    items: (_json['items'] as List)
        .map((item) => _item(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  ItineraryDetailItem _item(Map<String, dynamic> json) {
    final arrival = _date(json['plannedArrival']);
    final departure = _date(json['plannedDeparture']);
    final kind = switch (json['kind']) {
      'Visit' => ItineraryItemKind.visit,
      'Rest' => ItineraryItemKind.rest,
      _ => throw const FormatException('Invalid itinerary detail item kind.'),
    };
    if (json['itemId'] is! int ||
        json['sequenceNo'] is! int ||
        json['stayDurationMinutes'] is! int ||
        json['isMandatory'] is! bool ||
        json['isUnavailable'] is! bool ||
        arrival == null ||
        departure == null) {
      throw const FormatException('Invalid itinerary detail item.');
    }
    return ItineraryDetailItem(
      itemId: json['itemId'] as int,
      sequenceNo: json['sequenceNo'] as int,
      poiId: json['poiId'] as int?,
      poiName: json['poiName'] as String?,
      category: json['category'] as String?,
      itemKind: kind,
      plannedArrival: arrival,
      plannedDeparture: departure,
      travelDurationFromPreviousMinutes:
          json['travelDurationFromPreviousMinutes'] as int?,
      stayDurationMinutes: json['stayDurationMinutes'] as int,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble(),
      isMandatory: json['isMandatory'] as bool,
      recommendationReason: json['recommendationReason'] as String?,
      isUnavailable: json['isUnavailable'] as bool,
    );
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Invalid itinerary date.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const FormatException('Invalid itinerary date.');
    return parsed.toUtc();
  }
}
