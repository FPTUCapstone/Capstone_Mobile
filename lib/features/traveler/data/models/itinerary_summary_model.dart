import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_summary.dart';

final class ItinerarySummaryPageModel {
  const ItinerarySummaryPageModel._(this._json);

  factory ItinerarySummaryPageModel.fromJson(Map<String, dynamic> json) {
    if (json['items'] is! List ||
        json['page'] is! int ||
        json['pageSize'] is! int ||
        json['totalCount'] is! int) {
      throw const FormatException('Invalid itinerary list response.');
    }
    return ItinerarySummaryPageModel._(json);
  }

  final Map<String, dynamic> _json;

  ItinerarySummaryPage toEntity() => ItinerarySummaryPage(
    items: (_json['items'] as List)
        .map((item) => _summary(item))
        .toList(growable: false),
    page: _json['page'] as int,
    pageSize: _json['pageSize'] as int,
    totalCount: _json['totalCount'] as int,
  );

  static ItinerarySummary _summary(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['itineraryId'] is! int ||
        value['version'] is! int ||
        value['status'] is! String ||
        value['canManage'] is! bool ||
        value['stopCount'] is! int ||
        (value['title'] != null && value['title'] is! String) ||
        (value['openNavigationSessionId'] != null &&
            value['openNavigationSessionId'] is! int)) {
      throw const FormatException('Invalid itinerary list item.');
    }
    return ItinerarySummary(
      itineraryId: value['itineraryId'] as int,
      title: value['title'] as String?,
      version: value['version'] as int,
      status: value['status'] as String,
      validFrom: _date(value['validFrom']),
      validTo: _date(value['validTo']),
      canManage: value['canManage'] as bool,
      stopCount: value['stopCount'] as int,
      openNavigationSessionId: value['openNavigationSessionId'] as int?,
      transportMode: _transportMode(value['transportMode']),
      previewStopNames: _previewStopNames(value['previewStopNames']),
    );
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const FormatException('Invalid itinerary list date.');
    }
    return DateTime.parse(value);
  }

  static TransportMode? _transportMode(Object? value) {
    if (value is! String) return null;
    return switch (value.trim().toLowerCase()) {
      'walking' => TransportMode.walking,
      'motorbike' => TransportMode.motorbike,
      'car' => TransportMode.car,
      'publictransit' || 'public_transit' => TransportMode.publicTransit,
      _ => null,
    };
  }

  static List<String> _previewStopNames(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }
}
