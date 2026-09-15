import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

final class ItineraryGenerationModel {
  const ItineraryGenerationModel(this._json);

  factory ItineraryGenerationModel.fromJson(Map<String, dynamic> json) {
    if (json['schedulingRequestId'] is! int ||
        json['itineraryId'] is! int ||
        json['title'] is! String ||
        json['status'] is! String ||
        json['totalDurationMinutes'] is! int ||
        json['items'] is! List) {
      throw const FormatException('Invalid itinerary generation response.');
    }
    return ItineraryGenerationModel(json);
  }

  final Map<String, dynamic> _json;

  GeneratedItinerary toEntity() => GeneratedItinerary(
    schedulingRequestId: _json['schedulingRequestId'] as int,
    itineraryId: _json['itineraryId'] as int,
    title: _json['title'] as String,
    status: _json['status'] as String,
    totalEstimatedCost: (_json['totalEstimatedCost'] as num?)?.toDouble() ?? 0,
    totalDurationMinutes: _json['totalDurationMinutes'] as int,
    items: (_json['items'] as List)
        .map((item) => _itemFromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  GeneratedItineraryItem _itemFromJson(Map<String, dynamic> json) {
    final kind = json['itemKind'];
    final arrival = DateTime.tryParse(json['plannedArrival'] as String? ?? '');
    final departure = DateTime.tryParse(
      json['plannedDeparture'] as String? ?? '',
    );
    if (json['sequenceNo'] is! int ||
        json['stayDurationMinutes'] is! int ||
        json['isMandatory'] is! bool ||
        arrival == null ||
        departure == null ||
        kind is! String) {
      throw const FormatException('Invalid generated itinerary item.');
    }
    final itemKind = switch (kind) {
      'Visit' => ItineraryItemKind.visit,
      'Rest' => ItineraryItemKind.rest,
      _ => throw const FormatException(
        'Invalid generated itinerary item kind.',
      ),
    };
    return GeneratedItineraryItem(
      sequenceNo: json['sequenceNo'] as int,
      poiId: json['poiId'] as int?,
      poiName: json['poiName'] as String?,
      itemKind: itemKind,
      plannedArrival: arrival.toUtc(),
      plannedDeparture: departure.toUtc(),
      stayDurationMinutes: json['stayDurationMinutes'] as int,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble(),
      isMandatory: json['isMandatory'] as bool,
      recommendationReason: json['recommendationReason'] as String?,
    );
  }
}
