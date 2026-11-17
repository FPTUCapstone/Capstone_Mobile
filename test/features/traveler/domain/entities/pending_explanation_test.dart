import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/pending_explanation.dart';

void main() {
  group('PendingExplanation.forRoute', () {
    final pending = PendingExplanation(
      itineraryId: 10,
      createdAt: DateTime.utc(2026, 11, 17, 10),
      template: const {1: 'Template'},
    );

    test('returns the route extra when it belongs to this itinerary', () {
      expect(PendingExplanation.forRoute(pending, 10), same(pending));
    });

    test('ignores an extra that belongs to another itinerary', () {
      expect(PendingExplanation.forRoute(pending, 11), isNull);
    });

    test('ignores a missing extra and an extra of another type', () {
      expect(PendingExplanation.forRoute(null, 10), isNull);
      expect(PendingExplanation.forRoute('something else', 10), isNull);
    });
  });
}
