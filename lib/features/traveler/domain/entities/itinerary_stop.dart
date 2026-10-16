import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

/// One place in the ordered list the traveler sends to change an itinerary
/// (add, replace, remove, reorder, or change the transport of a leg).
final class ItineraryStop extends Equatable {
  const ItineraryStop({required this.poiId, this.transportModeToNext});

  final int poiId;

  /// Transport to the next stop; null uses the trip default. Ignored on the
  /// last stop.
  final TransportMode? transportModeToNext;

  ItineraryStop withMode(TransportMode? mode) =>
      ItineraryStop(poiId: poiId, transportModeToNext: mode);

  @override
  List<Object?> get props => [poiId, transportModeToNext];
}
