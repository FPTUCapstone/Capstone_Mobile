import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';

abstract interface class ItineraryRepository {
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  });

  Future<ItineraryDetail> getById(int itineraryId) =>
      throw UnimplementedError('Persisted itinerary detail is not available.');

  Future<ItineraryDetail> accept(int itineraryId) =>
      throw UnimplementedError('Persisted itinerary accept is not available.');

  Future<ItineraryDetail> regenerate({
    required int itineraryId,
    required String idempotencyKey,
  }) => throw UnimplementedError(
    'Persisted itinerary regeneration is not available.',
  );

  /// Saves a new version with exactly these visit stops (add, replace, remove,
  /// reorder, or change a leg's transport). Throws `StopInfeasibleFailure`
  /// when a stop would not fit.
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
  }) => throw UnimplementedError(
    'Persisted itinerary adjustment is not available.',
  );
}
