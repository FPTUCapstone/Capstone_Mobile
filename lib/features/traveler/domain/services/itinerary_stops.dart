import 'package:trip_mate_mobile/core/utils/trip_time_format.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';

/// Builds the `stops` list for an itinerary edit from the current version, so
/// every edit (leg transport, add, replace, remove, reorder) keeps the other
/// legs as they are.
abstract final class ItineraryStops {
  /// The visit stops in order, each with its own outgoing transport: the mode
  /// of the leg that leaves it, i.e. the next item's (visit or break)
  /// `transportModeFromPrevious`, as stored per visit by the backend.
  static List<ItineraryStop> current(ItineraryDetail detail) {
    final items = detail.items;
    final visits = detail.visitItems;
    return [
      for (var i = 0; i < visits.length; i++)
        ItineraryStop(
          poiId: visits[i].poiId!,
          transportModeToNext: i + 1 < visits.length
              ? _outgoingMode(items, visits[i])
              : null,
        ),
    ];
  }

  static TransportMode? _outgoingMode(
    List<ItineraryDetailItem> items,
    ItineraryDetailItem visit,
  ) {
    final index = items.indexOf(visit);
    return index >= 0 && index + 1 < items.length
        ? items[index + 1].transportModeFromPrevious
        : null;
  }

  /// Sets the transport of the leg that reaches [toPoiId].
  static List<ItineraryStop> withLegMode(
    List<ItineraryStop> stops, {
    required int toPoiId,
    required TransportMode mode,
  }) {
    final target = stops.indexWhere((stop) => stop.poiId == toPoiId);
    if (target <= 0) return List.unmodifiable(stops);
    return List.unmodifiable([
      for (var i = 0; i < stops.length; i++)
        i == target - 1 ? stops[i].withMode(mode) : stops[i],
    ]);
  }

  /// Adds [poiId] right after [afterPoiId] (at the end when not found). The
  /// new stop leaves with the trip default transport.
  static List<ItineraryStop> insertAfter(
    List<ItineraryStop> stops, {
    required int afterPoiId,
    required int poiId,
  }) {
    final index = stops.indexWhere((stop) => stop.poiId == afterPoiId);
    final position = index < 0 ? stops.length : index + 1;
    return List.unmodifiable([
      ...stops.take(position),
      ItineraryStop(poiId: poiId),
      ...stops.skip(position),
    ]);
  }

  /// Swaps [oldPoiId] for [newPoiId] at the same position and leg transport.
  static List<ItineraryStop> replace(
    List<ItineraryStop> stops, {
    required int oldPoiId,
    required int newPoiId,
  }) => List.unmodifiable([
    for (final stop in stops)
      stop.poiId == oldPoiId
          ? ItineraryStop(
              poiId: newPoiId,
              transportModeToNext: stop.transportModeToNext,
            )
          : stop,
  ]);

  static List<ItineraryStop> remove(List<ItineraryStop> stops, int poiId) =>
      List.unmodifiable(stops.where((stop) => stop.poiId != poiId));

  /// Puts the stops in [orderedPoiIds] order (dropping the others). A stop
  /// keeps its leg transport only when it still leads to the same next stop.
  static List<ItineraryStop> reorder(
    List<ItineraryStop> stops,
    List<int> orderedPoiIds,
  ) {
    final nextOf = <int, int?>{
      for (var i = 0; i < stops.length; i++)
        stops[i].poiId: i + 1 < stops.length ? stops[i + 1].poiId : null,
    };
    final modeOf = {
      for (final stop in stops) stop.poiId: stop.transportModeToNext,
    };
    return List.unmodifiable([
      for (var i = 0; i < orderedPoiIds.length; i++)
        ItineraryStop(
          poiId: orderedPoiIds[i],
          transportModeToNext:
              i + 1 < orderedPoiIds.length &&
                  nextOf[orderedPoiIds[i]] == orderedPoiIds[i + 1]
              ? modeOf[orderedPoiIds[i]]
              : null,
        ),
    ]);
  }

  /// Minutes each stop present in both versions moved (positive = later).
  /// Stops whose arrival did not change are left out.
  static Map<int, int> arrivalShifts(
    ItineraryDetail before,
    ItineraryDetail after,
  ) {
    final previous = {
      for (final item in before.visitItems) item.poiId!: item.plannedArrival,
    };
    final shifts = <int, int>{};
    for (final item in after.visitItems) {
      final old = previous[item.poiId];
      if (old == null) continue;
      final minutes = item.plannedArrival.difference(old).inMinutes;
      if (minutes != 0) shifts[item.poiId!] = minutes;
    }
    return shifts;
  }

  /// The visit after which a "lunch?" card belongs: the trip covers
  /// 11:00–13:30 (Vietnam time), no restaurant is planned, and this stop's
  /// departure is the closest to 12:00. Null when no card should be shown.
  static int? lunchSlotAfterItemId(ItineraryDetail detail) {
    final visits = detail.visitItems;
    if (visits.isEmpty || visits.any((item) => item.isFood)) return null;
    final start = detail.validFrom ?? detail.items.first.plannedArrival;
    final end = detail.validTo ?? detail.items.last.plannedDeparture;
    final noon = _coveredNoon(start, end);
    if (noon == null) return null;
    var best = visits.first;
    for (final item in visits.skip(1)) {
      if (item.plannedDeparture.difference(noon).abs() <
          best.plannedDeparture.difference(noon).abs()) {
        best = item;
      }
    }
    return best.itemId;
  }

  /// 12:00 (as a UTC instant) of the first trip day whose 11:00–13:30 lies
  /// inside [start]–[end].
  static DateTime? _coveredNoon(DateTime start, DateTime end) {
    final local = tripLocalTime(start);
    var dayStart = DateTime.utc(local.year, local.month, local.day);
    while (true) {
      final lunchFrom = dayStart
          .add(const Duration(hours: 11))
          .subtract(vietnamOffset);
      final lunchTo = dayStart
          .add(const Duration(hours: 13, minutes: 30))
          .subtract(vietnamOffset);
      if (lunchFrom.isAfter(end)) return null;
      if (!lunchFrom.isBefore(start) && !lunchTo.isAfter(end)) {
        return dayStart.add(const Duration(hours: 12)).subtract(vietnamOffset);
      }
      dayStart = dayStart.add(const Duration(days: 1));
    }
  }
}
