import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';

void main() {
  test('snapshot owns immutable collections rather than caller lists', () {
    final items = <ItineraryDetailItem>[];
    final snapshot = OfflineTripSnapshot(
      ownerId: 7,
      requestedItineraryId: 10,
      itinerary: ItineraryDetail(
        itineraryId: 11,
        schedulingRequestId: 1,
        title: 'Trip',
        version: 2,
        status: 'Active',
        validFrom: null,
        validTo: null,
        canManage: true,
        totalEstimatedCost: 0,
        totalDurationMinutes: 1,
        items: items,
      ),
      pois: const [],
      routes: const [],
      capturedAtUtc: DateTime.utc(2026),
    );
    expect(() => snapshot.itinerary.items.clear(), throwsUnsupportedError);
    expect(() => snapshot.pois.clear(), throwsUnsupportedError);
    expect(() => snapshot.routes.clear(), throwsUnsupportedError);
    expect(snapshot.requestedItineraryId, 10);
    expect(snapshot.itinerary.itineraryId, 11);
  });
}
