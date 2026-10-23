import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/trip_history/data/models/trip_records_json.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/demo_trip_records_repository.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';

/// Writes an entity the way the backend does (ids as JSON numbers).
Map<String, dynamic> _record(TripRecord record) {
  final base = <String, dynamic>{
    'kind': record.kind.wireKind,
    'id': record.id,
    'tab': switch (record.tab) {
      TripStatus.upcoming => 'Upcoming',
      TripStatus.completed => 'Completed',
      TripStatus.cancelled => 'Cancelled',
    },
    'title': record.title,
    'departureAtUtc': record.departureAtUtc.toIso8601String(),
    'status': record.status,
    'actions': {
      'canReview': record.actions.canReview,
      'canViewETicket': record.actions.canViewETicket,
      'ticketId': record.actions.ticketId,
      'canViewRefund': record.actions.canViewRefund,
    },
  };
  switch (record) {
    case BookingTripRecord():
      return {
        ...base,
        'tripType': 'TourBooking',
        'bookingCode': record.bookingCode,
        'participantCount': record.participantCount,
        'totalAmount': record.totalAmount,
        'reviewableRecord': {
          'kind': record.reviewableRecord.wireKind,
          'id': record.reviewableRecord.id,
        },
        'review': {
          'exists': record.review.exists,
          if (record.review.exists) 'reviewId': record.review.reviewId,
          if (record.review.exists) 'rating': record.review.rating,
        },
      };
    case ItineraryTripRecord():
      return {
        ...base,
        'tripType': 'SelfPlannedItinerary',
        'stopCount': record.stopCount,
        if (record.visitedCount != null) 'visitedCount': record.visitedCount,
        'reviewableRecord': null,
        'review': null,
      };
  }
}

Map<String, dynamic> _detail(TripRecordDetail detail) {
  switch (detail) {
    case BookingTripDetail():
      return {
        ..._record(detail.record),
        'tour': {
          'title': detail.tour.title,
          'destinationSummary': detail.tour.destinationSummary,
        },
        'schedule': {
          'startAtUtc': detail.schedule.startAtUtc.toIso8601String(),
          'endAtUtc': detail.schedule.endAtUtc.toIso8601String(),
          'meetingPoint': detail.schedule.meetingPoint,
        },
        'participants': {
          'adult': detail.participants.adult,
          'child': detail.participants.child,
          'infant': detail.participants.infant,
        },
        if (detail.cancellation != null)
          'cancellation': {
            'cancelledAtUtc': detail.cancellation!.cancelledAtUtc
                ?.toIso8601String(),
            'reason': detail.cancellation!.reason,
          },
        if (detail.refund != null)
          'refund': {
            'status': detail.refund!.status,
            'amount': detail.refund!.amount,
            'channel': detail.refund!.channel,
          },
      };
    case ItineraryTripDetail():
      return {
        ..._record(detail.record),
        if (detail.validFromUtc != null)
          'validFromUtc': detail.validFromUtc!.toIso8601String(),
        if (detail.validToUtc != null)
          'validToUtc': detail.validToUtc!.toIso8601String(),
        'stops': [
          for (final stop in detail.stops)
            {
              'sequenceNo': stop.sequenceNo,
              'poiId': stop.poiId,
              'poiName': stop.poiName,
              'plannedArrivalUtc': stop.plannedArrivalUtc?.toIso8601String(),
              'plannedDepartureUtc': stop.plannedDepartureUtc
                  ?.toIso8601String(),
              if (stop.visitStatus != null)
                'visitStatus': switch (stop.visitStatus!) {
                  TripVisitStatus.reached => 'Reached',
                  TripVisitStatus.skipped => 'Skipped',
                  TripVisitStatus.pending => 'Pending',
                },
              if (stop.reachedAtUtc != null)
                'reachedAtUtc': stop.reachedAtUtc!.toIso8601String(),
              if (stop.skippedAtUtc != null)
                'skippedAtUtc': stop.skippedAtUtc!.toIso8601String(),
            },
        ],
        if (detail.session != null)
          'session': {
            'startedAtUtc': detail.session!.startedAtUtc.toIso8601String(),
            'endedAtUtc': detail.session!.endedAtUtc?.toIso8601String(),
            'completionReason': detail.session!.completionReason,
          },
      };
  }
}

void main() {
  const repository = DemoTripRecordsRepository();

  Future<TripRecordPage> page(
    TripStatus tab, {
    TripRecordTypeFilter type = TripRecordTypeFilter.all,
    DateTime? start,
    DateTime? end,
    int number = 1,
    int size = 20,
  }) => repository.getPage(
    TripRecordsQuery(
      tab: tab,
      tripType: type,
      startDate: start,
      endDate: end,
      page: number,
      pageSize: size,
    ),
  );

  List<String> ids(TripRecordPage value) =>
      value.items.map((item) => '${item.kind.wireKind}:${item.id}').toList();

  Future<List<TripRecordDetail>> allDetails() async {
    final result = <TripRecordDetail>[];
    for (final tab in TripStatus.values) {
      for (final item in (await page(tab)).items) {
        result.add(await repository.getDetail(item.kind, item.id));
      }
    }
    return result;
  }

  group('contract guard', () {
    test('every list page passes the strict parser', () async {
      for (final tab in TripStatus.values) {
        final value = await page(tab);
        final wire = <String, dynamic>{
          'items': value.items.map(_record).toList(),
          if (value.summary != null)
            'summary': {
              'totalCompletedTrips': value.summary!.totalCompletedTrips,
              'totalVisitedPois': value.summary!.totalVisitedPois,
            },
          'page': value.page,
          'pageSize': value.pageSize,
          'totalCount': value.totalCount,
        };

        expect(value.items, isNotEmpty, reason: tab.name);
        expect(
          TripRecordsJson.page(jsonDecode(jsonEncode(wire))),
          value,
          reason: tab.name,
        );
      }
    });

    test('every detail passes the strict parser and round-trips', () async {
      final details = await allDetails();

      expect(details.length, greaterThanOrEqualTo(8));
      for (final detail in details) {
        expect(
          TripRecordsJson.detail(jsonDecode(jsonEncode(_detail(detail)))),
          detail,
        );
      }
    });
  });

  group('fixtures cover every state the screen renders', () {
    test('both kinds and all tabs', () async {
      final details = await allDetails();
      final bookings = details.whereType<BookingTripDetail>().toList();
      final itineraries = details.whereType<ItineraryTripDetail>().toList();

      bool any<T extends TripRecordDetail>(
        List<T> list,
        bool Function(T) test,
      ) => list.any(test);

      expect(
        any(
          bookings,
          (d) =>
              d.record.tab == TripStatus.completed &&
              d.record.actions.canReview &&
              !d.record.review.exists,
        ),
        isTrue,
      );
      expect(
        any(
          bookings,
          (d) =>
              d.record.tab == TripStatus.completed &&
              !d.record.actions.canReview &&
              d.record.review.exists,
        ),
        isTrue,
      );
      expect(
        any(
          bookings,
          (d) =>
              d.record.tab == TripStatus.upcoming &&
              d.record.actions.canViewETicket &&
              d.record.actions.ticketId != null,
        ),
        isTrue,
      );
      expect(
        any(
          bookings,
          (d) =>
              d.record.tab == TripStatus.cancelled &&
              d.record.actions.canViewRefund &&
              d.refund != null,
        ),
        isTrue,
      );
      expect(
        any(
          bookings,
          (d) =>
              d.record.tab == TripStatus.cancelled &&
              !d.record.actions.canViewRefund,
        ),
        isTrue,
      );
      expect(
        any(
          itineraries,
          (d) =>
              d.record.tab == TripStatus.completed &&
              (d.record.visitedCount ?? 0) < d.record.stopCount,
        ),
        isTrue,
      );
      expect(
        any(itineraries, (d) => d.session?.completionReason == 'Expired'),
        isTrue,
      );
      expect(
        any(itineraries, (d) => d.record.tab == TripStatus.upcoming),
        isTrue,
      );
      expect(
        any(itineraries, (d) => d.record.tab == TripStatus.cancelled),
        isTrue,
      );
    });

    test('actions agree with the record, as the backend guarantees', () async {
      for (final detail in await allDetails()) {
        final record = detail.record;
        switch (record) {
          case BookingTripRecord():
            expect(record.reviewableRecord.id, record.id);
            expect(
              record.actions.canReview,
              record.status == 'Completed' && !record.review.exists,
            );
            expect(
              record.actions.canViewETicket,
              record.actions.ticketId != null,
            );
            expect(
              record.actions.canViewRefund,
              record.status == 'Cancelled' &&
                  (detail as BookingTripDetail).refund != null,
            );
          case ItineraryTripRecord():
            expect(record.actions.canReview, isFalse);
            expect(record.actions.canViewETicket, isFalse);
            expect(record.actions.ticketId, isNull);
            expect(record.actions.canViewRefund, isFalse);
            final stops = (detail as ItineraryTripDetail).stops;
            if (record.tab == TripStatus.completed) {
              expect(record.stopCount, stops.length);
              expect(
                record.visitedCount,
                stops
                    .where((s) => s.visitStatus == TripVisitStatus.reached)
                    .length,
              );
            }
        }
      }
    });

    test('a list item is the record of its detail', () async {
      for (final tab in TripStatus.values) {
        for (final item in (await page(tab)).items) {
          expect((await repository.getDetail(item.kind, item.id)).record, item);
        }
      }
    });
  });

  group('list behaves like the backend list', () {
    test(
      'orders by departure desc, then bookings before itineraries, then id desc',
      () async {
        final value = await page(TripStatus.completed);

        expect(ids(value), [
          'commerceBooking:9001',
          'commerceBooking:9002',
          'itinerary:5001',
          'itinerary:5002',
        ]);
        expect(value.items[1].departureAtUtc, value.items[2].departureAtUtc);
      },
    );

    test('adds the summary on the Completed tab only', () async {
      expect(
        (await page(TripStatus.completed)).summary,
        const TripRecordSummary(totalCompletedTrips: 4, totalVisitedPois: 4),
      );
      expect((await page(TripStatus.upcoming)).summary, isNull);
      expect((await page(TripStatus.cancelled)).summary, isNull);
    });

    test('filters by trip type and keeps the summary in step', () async {
      final bookings = await page(
        TripStatus.completed,
        type: TripRecordTypeFilter.tourBooking,
      );
      final itineraries = await page(
        TripStatus.completed,
        type: TripRecordTypeFilter.selfPlannedItinerary,
      );

      expect(bookings.items.every((i) => i is BookingTripRecord), isTrue);
      expect(
        bookings.summary,
        const TripRecordSummary(totalCompletedTrips: 2, totalVisitedPois: 0),
      );
      expect(itineraries.items.every((i) => i is ItineraryTripRecord), isTrue);
      expect(
        itineraries.summary,
        const TripRecordSummary(totalCompletedTrips: 2, totalVisitedPois: 4),
      );
    });

    test('filters by Vietnam calendar days, inclusive of both ends', () async {
      // 9001 departs 2026-10-01T02:00Z, which is 09:00 on 2026-10-01 in Vietnam.
      final oneDay = await page(
        TripStatus.completed,
        start: DateTime.utc(2026, 10, 1),
        end: DateTime.utc(2026, 10, 1),
      );
      final before = await page(
        TripStatus.completed,
        start: DateTime.utc(2026, 9, 30),
        end: DateTime.utc(2026, 9, 30),
      );
      final onlyStart = await page(
        TripStatus.completed,
        start: DateTime.utc(2026, 10, 1),
      );
      final onlyEnd = await page(
        TripStatus.completed,
        end: DateTime.utc(2026, 8, 31),
      );

      expect(ids(oneDay), ['commerceBooking:9001']);
      expect(before.items, isEmpty);
      expect(ids(onlyStart), ['commerceBooking:9001']);
      expect(ids(onlyEnd), ['itinerary:5002']);
    });

    test('pages the result and keeps totalCount on every page', () async {
      final first = await page(TripStatus.completed, size: 3);
      final second = await page(TripStatus.completed, number: 2, size: 3);
      final beyond = await page(TripStatus.completed, number: 3, size: 3);

      expect(first.items, hasLength(3));
      expect(second.items, hasLength(1));
      expect(beyond.items, isEmpty);
      expect(
        [first.totalCount, second.totalCount, beyond.totalCount],
        [4, 4, 4],
      );
      expect([
        ...ids(first),
        ...ids(second),
      ], ids(await page(TripStatus.completed)));
      expect(first.pageSize, 3);
      expect(second.page, 2);
    });

    test('an empty result is a normal empty page', () async {
      final value = await page(
        TripStatus.cancelled,
        type: TripRecordTypeFilter.selfPlannedItinerary,
        start: DateTime.utc(2030, 1, 1),
      );

      expect(value.items, isEmpty);
      expect(value.totalCount, 0);
    });
  });

  group('detail', () {
    test('returns the booking and itinerary details', () async {
      expect(
        await repository.getDetail(TripRecordKind.commerceBooking, 9004),
        isA<BookingTripDetail>(),
      );
      expect(
        await repository.getDetail(TripRecordKind.itinerary, 5001),
        isA<ItineraryTripDetail>(),
      );
    });

    test(
      'an unknown record, or an id of the other kind, is not found',
      () async {
        await expectLater(
          repository.getDetail(TripRecordKind.itinerary, 999999),
          throwsA(isA<NotFoundFailure>()),
        );
        await expectLater(
          repository.getDetail(TripRecordKind.commerceBooking, 5001),
          throwsA(isA<NotFoundFailure>()),
        );
        await expectLater(
          repository.getDetail(TripRecordKind.itinerary, 9001),
          throwsA(isA<NotFoundFailure>()),
        );
      },
    );
  });
}
