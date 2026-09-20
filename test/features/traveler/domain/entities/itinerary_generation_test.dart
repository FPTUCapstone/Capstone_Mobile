import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';

void main() {
  test('formats a Vietnam planning time with its explicit UTC offset', () {
    final formatted = formatPlanningDateTime(DateTime(2026, 10, 20, 8, 0));

    expect(formatted, '2026-10-20T08:00:00.000+07:00');
  });

  test('normalizes mandatory POIs for a stable idempotency payload', () {
    const request = ItineraryGenerationRequest(
      startAt: '2026-10-20T08:00:00+07:00',
      timeZoneId: 'Asia/Ho_Chi_Minh',
      startLatitude: 16.0544,
      startLongitude: 108.2022,
      explorationLatitude: 16.0471,
      explorationLongitude: 108.2068,
      returnToStart: true,
      availableMinutes: 480,
      transportMode: TransportMode.motorbike,
      searchRadiusKm: 10,
      mandatoryPoiIds: [28, 12],
      restPreference: RestPreference.auto,
    );

    expect(request.normalizedMandatoryPoiIds, [12, 28]);
    expect(request.toJson()['transportMode'], 'Motorbike');
    expect(request.toJson()['restPreference'], 'Auto');
  });
}
