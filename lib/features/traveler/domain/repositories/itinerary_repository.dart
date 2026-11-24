import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_weather_tips.dart';

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
  /// reorder, or change a leg's transport). [removalReasons] tells, by POI ID,
  /// why a stop was left out. Throws `StopInfeasibleFailure` when a stop would
  /// not fit.
  Future<ItineraryDetail> updateStops({
    required int itineraryId,
    required List<ItineraryStop> stops,
    required String idempotencyKey,
    Map<int, StopRemovalReason> removalReasons = const {},
  }) => throw UnimplementedError(
    'Persisted itinerary adjustment is not available.',
  );

  /// UC-10: what to bring because of that day's weather, as the backend worked
  /// it out. `null` means "not available" (too far ahead, service off, any
  /// failure); callers hide the card and never guess.
  Future<ItineraryWeatherTips?> getWeatherTips(int itineraryId) async => null;
}
