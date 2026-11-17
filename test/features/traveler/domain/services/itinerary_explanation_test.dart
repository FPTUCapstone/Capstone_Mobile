import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/pending_explanation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/services/itinerary_explanation.dart';

ItineraryDetailItem _item(int sequenceNo, String? friendly) =>
    ItineraryDetailItem(
      itemId: sequenceNo * 100,
      sequenceNo: sequenceNo,
      poiId: sequenceNo,
      poiName: 'Place $sequenceNo',
      category: null,
      itemKind: ItineraryItemKind.visit,
      plannedArrival: DateTime.utc(2026, 9, 20, 1),
      plannedDeparture: DateTime.utc(2026, 9, 20, 2),
      travelDurationFromPreviousMinutes: null,
      stayDurationMinutes: 60,
      estimatedCost: null,
      isMandatory: false,
      recommendationReason: 'Reason',
      isUnavailable: false,
      friendlyExplanation: friendly,
    );

ItineraryDetail _detail(
  List<ItineraryDetailItem> items, {
  int version = 1,
  String title = 'Trip',
}) => ItineraryDetail(
  itineraryId: 10,
  schedulingRequestId: 20,
  title: title,
  version: version,
  status: 'Draft',
  validFrom: null,
  validTo: null,
  canManage: true,
  totalEstimatedCost: 0,
  totalDurationMinutes: 60,
  items: items,
);

GeneratedItineraryItem _generated(int sequenceNo, String? friendly) =>
    GeneratedItineraryItem(
      sequenceNo: sequenceNo,
      itemKind: ItineraryItemKind.visit,
      plannedArrival: DateTime.utc(2026, 9, 20, 1),
      plannedDeparture: DateTime.utc(2026, 9, 20, 2),
      stayDurationMinutes: 60,
      isMandatory: false,
      friendlyExplanation: friendly,
    );

GeneratedItinerary _generatedItinerary({required bool pending}) =>
    GeneratedItinerary(
      schedulingRequestId: 1,
      itineraryId: 10,
      title: 'Trip',
      status: 'Draft',
      totalEstimatedCost: 0,
      totalDurationMinutes: 60,
      explanationPending: pending,
      items: [_generated(1, '  Template A  '), _generated(2, null)],
    );

void main() {
  test('the refresh delays are 20, 45, 75 and 110 seconds', () {
    expect(explanationRefreshDelays.map((delay) => delay.inSeconds), [
      20,
      45,
      75,
      110,
    ]);
  });

  group('hasNewExplanation', () {
    const template = {1: 'Template A', 2: ''};

    test('is false while the sentences equal the template', () {
      expect(
        hasNewExplanation(template, [_item(1, 'Template A'), _item(2, null)]),
        isFalse,
      );
      expect(hasNewExplanation(template, [_item(1, '  Template A ')]), isFalse);
    });

    test('is false for empty, whitespace-only and null sentences', () {
      expect(
        hasNewExplanation(template, [_item(1, ''), _item(2, '   ')]),
        isFalse,
      );
      expect(hasNewExplanation(template, [_item(1, null)]), isFalse);
    });

    test('is true when one stop has a different non-empty sentence', () {
      expect(
        hasNewExplanation(template, [_item(1, 'Template A'), _item(2, 'AI')]),
        isTrue,
      );
    });

    test(
      'treats a sentence for a sequenceNo missing from the template as new',
      () {
        expect(hasNewExplanation(template, [_item(7, 'AI')]), isTrue);
      },
    );
  });

  group('mergeExplanations', () {
    test('copies only friendlyExplanation and keeps the rest of current', () {
      final current = _detail([_item(1, 'Template A'), _item(2, null)]);
      final fresh = _detail(
        [_item(1, 'AI'), _item(2, null)],
        version: 9,
        title: 'Other',
      );

      final merged = mergeExplanations(current, fresh);

      expect(merged.items[0].friendlyExplanation, 'AI');
      expect(merged.items[1].friendlyExplanation, isNull);
      expect(merged.items[0].itemId, 100);
      expect(merged.version, 1);
      expect(merged.title, 'Trip');
    });

    test('ignores blank fresh sentences and unknown sequence numbers', () {
      final current = _detail([_item(1, 'Template A')]);
      final fresh = _detail([_item(1, '   '), _item(5, 'AI')]);

      expect(identical(mergeExplanations(current, fresh), current), isTrue);
    });

    test('returns the same instance when nothing changes', () {
      final current = _detail([_item(1, 'Template A')]);

      expect(
        identical(
          mergeExplanations(current, _detail([_item(1, 'Template A')])),
          current,
        ),
        isTrue,
      );
    });
  });

  group('GeneratedItinerary.pendingExplanation', () {
    final createdAt = DateTime.utc(2026, 11, 17, 10);

    test('is null when the explanation is not pending', () {
      expect(
        _generatedItinerary(pending: false).pendingExplanation(createdAt),
        isNull,
      );
    });

    test('keeps the id, the time and the trimmed template sentences', () {
      final pending = _generatedItinerary(
        pending: true,
      ).pendingExplanation(createdAt)!;

      expect(
        pending,
        PendingExplanation(
          itineraryId: 10,
          createdAt: createdAt,
          template: const {1: 'Template A', 2: ''},
        ),
      );
    });
  });
}
