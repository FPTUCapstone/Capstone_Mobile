import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

abstract interface class ItineraryRepository {
  Future<GeneratedItinerary> generate({
    required ItineraryGenerationRequest request,
    required String idempotencyKey,
  });
}
