import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/operator_finance/domain/entities/revenue_query.dart';

void main() {
  test(
    'calendar dates and equality ignore time of day, never shift timezone',
    () {
      final query = RevenueQuery(
        startDate: DateTime(2026, 12, 1, 23),
        endDate: DateTime(2026, 12, 31, 1),
      );
      expect(
        query,
        RevenueQuery(
          startDate: DateTime(2026, 12),
          endDate: DateTime(2026, 12, 31),
        ),
      );
      expect(query.startDate, DateTime(2026, 12));
      expect(query.isValid, isTrue);
      expect(
        query.copyWith(tourId: 19, page: 2).copyWith(clearTour: true).tourId,
        isNull,
      );
    },
  );

  test(
    'same day valid, reversed range and invalid paging/granularity rejected',
    () {
      final query = RevenueQuery(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 1),
      );
      expect(query.isValid, isTrue);
      expect(
        query.copyWith(endDate: DateTime(2025, 12, 31)).validationError,
        isNotNull,
      );
      expect(query.copyWith(page: 0).isValid, isFalse);
      expect(query.copyWith(pageSize: 101).isValid, isFalse);
      expect(query.copyWith(granularity: 'hourly').isValid, isFalse);
      expect(query.copyWith(tourId: -1).isValid, isFalse);
    },
  );
}
