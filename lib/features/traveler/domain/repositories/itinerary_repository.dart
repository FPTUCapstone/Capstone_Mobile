import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

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

  Future<ItineraryDetail> adjustItems({
    required int itineraryId,
    required List<int> orderedVisitPoiIds,
    required String idempotencyKey,
  }) => throw UnimplementedError(
    'Persisted itinerary adjustment is not available.',
  );
}
