import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';

/// Parses the Backend `NavigationSessionResponse`.
abstract final class NavigationSessionModel {
  static NavigationSession fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final startedAt = _date(json['startedAtUtc']);
    if (json['sessionId'] is! int ||
        json['itineraryId'] is! int ||
        json['itineraryVersion'] is! int ||
        items is! List ||
        startedAt == null) {
      throw const FormatException('Invalid navigation session response.');
    }
    return NavigationSession(
      sessionId: json['sessionId'] as int,
      itineraryId: json['itineraryId'] as int,
      itineraryVersion: json['itineraryVersion'] as int,
      state: _state(json['state']),
      completionReason: _completionReason(json['completionReason']),
      startedAt: startedAt,
      expiresAt: _date(json['expiresAtUtc']),
      endedAt: _date(json['endedAtUtc']),
      exploringItemId: _optionalInt(json['exploringItemId']),
      nextItemId: _optionalInt(json['nextItemId']),
      items: _numberStops(
        items.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Invalid navigation session item.');
          }
          return _item(item);
        }),
      ),
      transportMode: _transportMode(json['transportMode']),
    );
  }

  /// Numbers the stops 1..n in itinerary order; sequence numbers can skip
  /// values where a break sits between two stops.
  static List<NavigationSessionItem> _numberStops(
    Iterable<NavigationSessionItem> items,
  ) {
    final ordered = items.toList()
      ..sort((a, b) => a.sequenceNo.compareTo(b.sequenceNo));
    final numbers = {
      for (var index = 0; index < ordered.length; index++)
        ordered[index].itemId: index + 1,
    };
    return items
        .map(
          (item) => NavigationSessionItem(
            itemId: item.itemId,
            sequenceNo: item.sequenceNo,
            poiId: item.poiId,
            poiName: item.poiName,
            latitude: item.latitude,
            longitude: item.longitude,
            plannedArrival: item.plannedArrival,
            plannedDeparture: item.plannedDeparture,
            isMandatory: item.isMandatory,
            status: item.status,
            reachedAt: item.reachedAt,
            skippedAt: item.skippedAt,
            stopNumber: numbers[item.itemId],
            transportModeFromPrevious: item.transportModeFromPrevious,
          ),
        )
        .toList(growable: false);
  }

  // Optional: older Backends omit it and manual itineraries send null; an
  // unknown mode falls back to the default routing profile.
  static TransportMode? _transportMode(Object? value) => switch (value) {
    'Walking' => TransportMode.walking,
    'Motorbike' => TransportMode.motorbike,
    'Car' => TransportMode.car,
    'PublicTransit' => TransportMode.publicTransit,
    _ => null,
  };

  static NavigationSessionItem _item(Map<String, dynamic> json) {
    final plannedArrival = _date(json['plannedArrivalUtc']);
    final plannedDeparture = _date(json['plannedDepartureUtc']);
    if (json['itemId'] is! int ||
        json['sequenceNo'] is! int ||
        json['poiId'] is! int ||
        json['poiName'] is! String ||
        json['latitude'] is! num ||
        json['longitude'] is! num ||
        json['isMandatory'] is! bool ||
        plannedArrival == null ||
        plannedDeparture == null) {
      throw const FormatException('Invalid navigation session item.');
    }
    return NavigationSessionItem(
      itemId: json['itemId'] as int,
      sequenceNo: json['sequenceNo'] as int,
      poiId: json['poiId'] as int,
      poiName: json['poiName'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      plannedArrival: plannedArrival,
      plannedDeparture: plannedDeparture,
      isMandatory: json['isMandatory'] as bool,
      status: switch (json['status']) {
        'Pending' => NavigationItemStatus.pending,
        'Skipped' => NavigationItemStatus.skipped,
        'Reached' => NavigationItemStatus.reached,
        _ => throw const FormatException('Invalid navigation item status.'),
      },
      reachedAt: _date(json['reachedAtUtc']),
      skippedAt: _date(json['skippedAtUtc']),
      transportModeFromPrevious: _transportMode(
        json['transportModeFromPrevious'],
      ),
    );
  }

  static NavigationSessionState _state(Object? value) => switch (value) {
    'Navigating' => NavigationSessionState.navigating,
    'Exploring' => NavigationSessionState.exploring,
    'Completed' => NavigationSessionState.completed,
    _ => throw const FormatException('Invalid navigation session state.'),
  };

  static NavigationCompletionReason? _completionReason(Object? value) =>
      switch (value) {
        null => null,
        'RouteFinished' => NavigationCompletionReason.routeFinished,
        'TravelerStopped' => NavigationCompletionReason.travelerStopped,
        'Expired' => NavigationCompletionReason.expired,
        _ => throw const FormatException(
          'Invalid navigation completion reason.',
        ),
      };

  static int? _optionalInt(Object? value) {
    if (value == null) return null;
    if (value is! int) throw const FormatException('Invalid navigation id.');
    return value;
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) throw const FormatException('Invalid navigation date.');
    return parsed.toUtc();
  }
}
