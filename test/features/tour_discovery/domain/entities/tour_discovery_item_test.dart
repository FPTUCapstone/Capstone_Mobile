import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/tour_discovery/domain/entities/tour_discovery_item.dart';
import 'package:trip_mate_mobile/features/tour_discovery/presentation/widgets/tour_discovery_meta_widgets.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

void main() {
  group('TourDiscoveryItem Data Fidelity & Round-Trip', () {
    test(
      'preserves non-null representativeScheduleId and currency round-trip',
      () {
        final summary = TourSummary(
          tourId: 'tour_101',
          title: 'Di Sản Miền Trung',
          destinations: const ['Huế', 'Đà Nẵng'],
          operatorName: 'Central Heritage',
          durationDays: 3,
          basePrice: 2500000,
          currency: 'VND',
          representativeScheduleId: 'sch_heritage_999',
          departureAtUtc: DateTime.utc(2026, 11, 20, 7),
          availabilityStatus: AvailabilityStatus.available,
          remainingSlots: 8,
          thumbnailUrl: 'https://example.com/tour.jpg',
          aggregateRating: 4.85,
        );

        final item = TourDiscoveryItem.fromSummary(summary);

        expect(item.id, 'tour_101');
        expect(item.title, 'Di Sản Miền Trung');
        expect(item.representativeScheduleId, 'sch_heritage_999');
        expect(item.currency, 'VND');
        expect(item.destinationsList, const ['Huế', 'Đà Nẵng']);
        expect(item.destinations, 'Huế · Đà Nẵng');

        final roundTrip = item.toSummary();
        expect(roundTrip, equals(summary));
        expect(roundTrip.representativeScheduleId, 'sch_heritage_999');
        expect(roundTrip.currency, 'VND');
        expect(roundTrip.destinations, const ['Huế', 'Đà Nẵng']);
      },
    );

    test('preserves null representativeScheduleId and non-VND currency', () {
      final summary = TourSummary(
        tourId: 'tour_usd',
        title: 'International Traveler Central Pass',
        destinations: const ['Đà Nẵng', 'Hội An'],
        operatorName: 'Global Explorer',
        durationDays: 2,
        basePrice: 150,
        currency: 'USD',
        representativeScheduleId: null,
        departureAtUtc: DateTime.utc(2026, 12, 1, 9),
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 2,
        thumbnailUrl: null,
        aggregateRating: 5.0,
      );

      final item = TourDiscoveryItem.fromSummary(summary);

      expect(item.representativeScheduleId, isNull);
      expect(item.currency, 'USD');

      final roundTrip = item.toSummary();
      expect(roundTrip, equals(summary));
      expect(roundTrip.representativeScheduleId, isNull);
      expect(roundTrip.currency, 'USD');
    });

    test('preserves empty destinations list without delimiter corruption', () {
      final summary = TourSummary(
        tourId: 'tour_empty_dest',
        title: 'Mystery Central Tour',
        destinations: const [],
        operatorName: 'Mystery Travel',
        durationDays: 1,
        basePrice: 500000,
        currency: 'VND',
        representativeScheduleId: null,
        departureAtUtc: null,
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 20,
      );

      final item = TourDiscoveryItem.fromSummary(summary);

      expect(item.destinationsList, isEmpty);
      expect(item.destinations, '');

      final roundTrip = item.toSummary();
      expect(roundTrip, equals(summary));
      expect(roundTrip.destinations, isEmpty);
    });

    test('preserves single destination without delimiter corruption', () {
      final summary = TourSummary(
        tourId: 'tour_single_dest',
        title: 'Bà Nà Hills Day Trip',
        destinations: const ['Bà Nà Hills'],
        operatorName: 'Danang Travel',
        durationDays: 1,
        basePrice: 1200000,
        currency: 'VND',
        representativeScheduleId: 'sch_bana_1',
        departureAtUtc: null,
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 15,
      );

      final item = TourDiscoveryItem.fromSummary(summary);

      expect(item.destinationsList, const ['Bà Nà Hills']);
      expect(item.destinations, 'Bà Nà Hills');

      final roundTrip = item.toSummary();
      expect(roundTrip, equals(summary));
      expect(roundTrip.destinations, const ['Bà Nà Hills']);
    });

    test('preserves destination strings containing delimiter literal', () {
      final summary = TourSummary(
        tourId: 'tour_delim',
        title: 'Cầu Vàng & Sông Hương',
        destinations: const ['Bà Nà · Cầu Vàng', 'Huế · Sông Hương'],
        operatorName: 'Central Eco',
        durationDays: 2,
        basePrice: 1800000,
        currency: 'VND',
        representativeScheduleId: 'sch_delim',
        departureAtUtc: null,
        availabilityStatus: AvailabilityStatus.available,
        remainingSlots: 5,
      );

      final item = TourDiscoveryItem.fromSummary(summary);

      // Exact ordered elements are preserved without split corruption
      expect(item.destinationsList, const [
        'Bà Nà · Cầu Vàng',
        'Huế · Sông Hương',
      ]);
      expect(item.destinations, 'Bà Nà · Cầu Vàng · Huế · Sông Hương');

      final roundTrip = item.toSummary();
      expect(roundTrip, equals(summary));
      expect(roundTrip.destinations.length, 2);
      expect(roundTrip.destinations[0], 'Bà Nà · Cầu Vàng');
      expect(roundTrip.destinations[1], 'Huế · Sông Hương');
    });

    test(
      'supports backward-compatible constructor with legacy destinations string',
      () {
        const item = TourDiscoveryItem(
          id: 'legacy_tour',
          title: 'Legacy Tour Title',
          destinations: 'Hội An · Mỹ Sơn',
          operatorName: 'Heritage Operator',
          durationDays: 1,
          priceVnd: 750000,
        );

        expect(item.destinations, 'Hội An · Mỹ Sơn');
        expect(item.destinationsList, const ['Hội An', 'Mỹ Sơn']);
        expect(item.currency, 'VND');
        expect(item.representativeScheduleId, isNull);

        final summary = item.toSummary();
        expect(summary.destinations, const ['Hội An', 'Mỹ Sơn']);
        expect(summary.currency, 'VND');
        expect(summary.representativeScheduleId, isNull);
      },
    );

    test('supports canonical destinationsList in const constructor', () {
      const item = TourDiscoveryItem(
        id: 'canonical_tour',
        title: 'Canonical Tour Title',
        destinationsList: ['Đà Nẵng', 'Hội An'],
        operatorName: 'Heritage Operator',
        durationDays: 2,
        priceVnd: 1500000,
        currency: 'VND',
        representativeScheduleId: 'sch_canon_01',
      );

      expect(item.destinationsList, const ['Đà Nẵng', 'Hội An']);
      expect(item.destinations, 'Đà Nẵng · Hội An');
      expect(item.representativeScheduleId, 'sch_canon_01');

      final summary = item.toSummary();
      expect(summary.destinations, const ['Đà Nẵng', 'Hội An']);
      expect(summary.representativeScheduleId, 'sch_canon_01');
    });

    test('equatable equality compares canonical list and contract fields', () {
      const itemA = TourDiscoveryItem(
        id: 'tour_eq',
        title: 'Equal Tour',
        destinations: 'Huế · Sông Hương',
        operatorName: 'Op',
        durationDays: 1,
        priceVnd: 100,
        currency: 'VND',
        representativeScheduleId: 'sch_eq',
      );

      const itemB = TourDiscoveryItem(
        id: 'tour_eq',
        title: 'Equal Tour',
        destinationsList: ['Huế', 'Sông Hương'],
        operatorName: 'Op',
        durationDays: 1,
        priceVnd: 100,
        currency: 'VND',
        representativeScheduleId: 'sch_eq',
      );

      const itemDifferentSchedule = TourDiscoveryItem(
        id: 'tour_eq',
        title: 'Equal Tour',
        destinationsList: ['Huế', 'Sông Hương'],
        operatorName: 'Op',
        durationDays: 1,
        priceVnd: 100,
        currency: 'VND',
        representativeScheduleId: 'sch_diff',
      );

      const itemDifferentCurrency = TourDiscoveryItem(
        id: 'tour_eq',
        title: 'Equal Tour',
        destinationsList: ['Huế', 'Sông Hương'],
        operatorName: 'Op',
        durationDays: 1,
        priceVnd: 100,
        currency: 'USD',
        representativeScheduleId: 'sch_eq',
      );

      expect(itemA, equals(itemB));
      expect(itemA, isNot(equals(itemDifferentSchedule)));
      expect(itemA, isNot(equals(itemDifferentCurrency)));
    });
  });

  group('Currency Formatting & Integrity (formatTourDiscoveryPrice)', () {
    test('formats standard VND amounts using Vietnamese Dong convention', () {
      expect(formatTourDiscoveryPrice(850000, 'VND'), '850,000 VND');
      expect(formatTourDiscoveryPrice(1250000, 'vnd'), '1,250,000 VND');
      expect(formatTourDiscoveryPrice(5600000), '5,600,000 VND');
    });

    test('preserves free label for zero VND amounts', () {
      expect(formatTourDiscoveryPrice(0, 'VND'), 'Free');
    });

    test(
      'formats non-VND currencies with actual currency code and thousands separators',
      () {
        expect(formatTourDiscoveryPrice(150, 'USD'), '150 USD');
        expect(formatTourDiscoveryPrice(1500, 'USD'), '1,500 USD');
        expect(formatTourDiscoveryPrice(1250000, 'EUR'), '1,250,000 EUR');
        expect(formatTourDiscoveryPrice(50000, 'JPY'), '50,000 JPY');
      },
    );

    test(
      'never assumes non-VND is VND, preventing silent currency mislabeling',
      () {
        final formattedUsd = formatTourDiscoveryPrice(250, 'USD');
        expect(formattedUsd, isNot(contains('VND')));
        expect(formattedUsd, '250 USD');
      },
    );
  });
}
