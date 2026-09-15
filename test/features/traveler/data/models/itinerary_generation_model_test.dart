import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_generation_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

void main() {
  test(
    'parses the successful scheduling response without fabricating fields',
    () {
      final result = ItineraryGenerationModel.fromJson({
        'schedulingRequestId': 24,
        'itineraryId': 91,
        'title': 'Generated itinerary - 20 Oct 2026',
        'status': 'Draft',
        'totalEstimatedCost': 650000,
        'totalDurationMinutes': 455,
        'items': [
          {
            'sequenceNo': 1,
            'poiId': 12,
            'poiName': 'Marble Mountains',
            'itemKind': 'Visit',
            'plannedArrival': '2026-10-20T08:30:00Z',
            'plannedDeparture': '2026-10-20T10:00:00Z',
            'stayDurationMinutes': 90,
            'estimatedCost': 40000,
            'isMandatory': true,
            'recommendationReason': 'Mandatory location',
          },
        ],
      }).toEntity();

      expect(result.itineraryId, 91);
      expect(result.items.single.isMandatory, isTrue);
      expect(result.items.single.itemKind, ItineraryItemKind.visit);
    },
  );
}
