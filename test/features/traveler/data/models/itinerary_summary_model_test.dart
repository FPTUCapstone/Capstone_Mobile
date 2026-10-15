import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/itinerary_summary_model.dart';

Map<String, dynamic> itinerarySummaryJson({
  int itineraryId = 60014,
  String status = 'Active',
  Object? openNavigationSessionId = 10,
}) => {
  'itineraryId': itineraryId,
  'schedulingRequestId': 70,
  'title': 'Generated itinerary - 10 Oct 2026',
  'version': 1,
  'status': status,
  'validFrom': '2026-10-10T02:03:53.618603+00:00',
  'validTo': '2026-10-10T04:40:53.618603+00:00',
  'canManage': true,
  'stopCount': 2,
  'openNavigationSessionId': openNavigationSessionId,
};

Map<String, dynamic> itinerarySummaryPageJson(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int totalCount = -1,
}) => {
  'items': items,
  'page': page,
  'pageSize': 20,
  'totalCount': totalCount < 0 ? items.length : totalCount,
};

void main() {
  test('parses the trip list page', () {
    final page = ItinerarySummaryPageModel.fromJson(
      itinerarySummaryPageJson([
        itinerarySummaryJson(),
        itinerarySummaryJson(
          itineraryId: 60015,
          status: 'Draft',
          openNavigationSessionId: null,
        ),
      ]),
    ).toEntity();

    expect(page.totalCount, 2);
    final trip = page.items.first;
    expect(trip.itineraryId, 60014);
    expect(trip.title, 'Generated itinerary - 10 Oct 2026');
    expect(trip.validFrom, DateTime.utc(2026, 10, 10, 2, 3, 53, 618, 603));
    expect(trip.stopCount, 2);
    expect(trip.isTripInProgress, isTrue);
    expect(page.items.last.isTripInProgress, isFalse);
  });

  test('rejects a malformed trip', () {
    expect(
      () => ItinerarySummaryPageModel.fromJson(
        itinerarySummaryPageJson([
          {...itinerarySummaryJson(), 'stopCount': '2'},
        ]),
      ).toEntity(),
      throwsFormatException,
    );
    expect(
      () => ItinerarySummaryPageModel.fromJson({'items': <Object>[]}),
      throwsFormatException,
    );
  });
}
