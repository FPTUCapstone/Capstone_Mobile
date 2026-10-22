import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/trip_history/data/models/trip_records_json.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';

Map<String, dynamic> _actions({
  bool canReview = true,
  bool canViewETicket = true,
  Object? ticketId = 77,
  bool canViewRefund = false,
}) => {
  'canReview': canReview,
  'canViewETicket': canViewETicket,
  'ticketId': ticketId,
  'canViewRefund': canViewRefund,
};

Map<String, dynamic> _booking([Map<String, dynamic> over = const {}]) => {
  'kind': 'commerceBooking',
  'id': 123,
  'tripType': 'TourBooking',
  'tab': 'Completed',
  'title': 'Hoi An Lantern Tour',
  'departureAtUtc': '2026-10-01T02:00:00+00:00',
  'status': 'Completed',
  'bookingCode': 'TM-000123',
  'participantCount': 2,
  'totalAmount': 3200000.00,
  'reviewableRecord': {'kind': 'commerceBooking', 'id': 123},
  'actions': _actions(),
  'review': {'exists': false},
  ...over,
};

Map<String, dynamic> _itinerary([Map<String, dynamic> over = const {}]) => {
  'kind': 'itinerary',
  'id': 45,
  'tripType': 'SelfPlannedItinerary',
  'tab': 'Completed',
  'title': 'Da Nang 2 days',
  'departureAtUtc': '2026-09-20T01:00:00+00:00',
  'status': 'Completed',
  'stopCount': 6,
  'visitedCount': 5,
  'reviewableRecord': null,
  'actions': _actions(canReview: false, canViewETicket: false, ticketId: null),
  'review': null,
  ...over,
};

Map<String, dynamic> _page(
  List<Map<String, dynamic>> items, [
  Map<String, dynamic> over = const {},
]) => {
  'items': items,
  'summary': {'totalCompletedTrips': 14, 'totalVisitedPois': 63},
  'page': 1,
  'pageSize': 20,
  'totalCount': 14,
  ...over,
};

/// Round-trips through JSON text exactly as Dio would hand the body over.
Object? _wire(Object? value) => jsonDecode(jsonEncode(value));

TripRecordPage _parsePage(Map<String, dynamic> body) =>
    TripRecordsJson.page(_wire(body));

void main() {
  group('TripRecordsJson.page', () {
    test('parses a booking and an itinerary', () {
      final page = _parsePage(_page([_booking(), _itinerary()]));

      expect(page.page, 1);
      expect(page.pageSize, 20);
      expect(page.totalCount, 14);
      expect(page.summary?.totalCompletedTrips, 14);
      expect(page.summary?.totalVisitedPois, 63);
      expect(page.items, hasLength(2));

      final booking = page.items[0] as BookingTripRecord;
      expect(booking.kind, TripRecordKind.commerceBooking);
      expect(booking.id, 123);
      expect(booking.tab, TripStatus.completed);
      expect(booking.title, 'Hoi An Lantern Tour');
      expect(booking.departureAtUtc, DateTime.utc(2026, 10, 1, 2));
      expect(booking.departureAtUtc.isUtc, isTrue);
      expect(booking.status, 'Completed');
      expect(booking.bookingCode, 'TM-000123');
      expect(booking.participantCount, 2);
      expect(booking.totalAmount, 3200000);
      expect(
        booking.reviewableRecord,
        const ReviewableRecordRef(
          kind: ReviewableRecordKind.commerceBooking,
          id: 123,
        ),
      );
      expect(booking.actions.canReview, isTrue);
      expect(booking.actions.canViewETicket, isTrue);
      expect(booking.actions.ticketId, 77);
      expect(booking.actions.canViewRefund, isFalse);
      expect(booking.review.exists, isFalse);
      expect(booking.review.reviewId, isNull);
      expect(booking.review.rating, isNull);

      final itinerary = page.items[1] as ItineraryTripRecord;
      expect(itinerary.kind, TripRecordKind.itinerary);
      expect(itinerary.id, 45);
      expect(itinerary.stopCount, 6);
      expect(itinerary.visitedCount, 5);
      expect(itinerary.actions.ticketId, isNull);
    });

    test('maps every tab to a TripStatus', () {
      final page = _parsePage(
        _page([
          _booking({
            'id': 1,
            'tab': 'Upcoming',
            'reviewableRecord': {'kind': 'commerceBooking', 'id': 1},
          }),
          _booking({
            'id': 2,
            'tab': 'Completed',
            'reviewableRecord': {'kind': 'commerceBooking', 'id': 2},
          }),
          _booking({
            'id': 3,
            'tab': 'Cancelled',
            'reviewableRecord': {'kind': 'commerceBooking', 'id': 3},
          }),
        ]),
      );

      expect(page.items.map((item) => item.tab), [
        TripStatus.upcoming,
        TripStatus.completed,
        TripStatus.cancelled,
      ]);
    });

    test('leaves the summary null when the tab has none', () {
      expect(_parsePage(_page([], {'summary': null})).summary, isNull);

      final omitted = _page([])..remove('summary');
      expect(_parsePage(omitted).summary, isNull);
    });

    test('parses a reviewed booking with its review id and rating', () {
      final page = _parsePage(
        _page([
          _booking({
            'actions': _actions(canReview: false),
            'review': {'exists': true, 'reviewId': 41, 'rating': 4},
          }),
        ]),
      );

      final booking = page.items.single as BookingTripRecord;
      expect(booking.review.exists, isTrue);
      expect(booking.review.reviewId, 41);
      expect(booking.review.rating, 4);
      expect(booking.actions.canReview, isFalse);
    });

    test('accepts an itinerary without a visitedCount', () {
      final item = _itinerary({'tab': 'Upcoming', 'status': 'Active'})
        ..remove('visitedCount');

      final record =
          _parsePage(_page([item])).items.single as ItineraryTripRecord;

      expect(record.visitedCount, isNull);
      expect(record.tab, TripStatus.upcoming);
    });

    test('rounds a decimal amount to whole VND', () {
      final page = _parsePage(
        _page([
          _booking({'totalAmount': 3200000.4}),
        ]),
      );

      expect((page.items.single as BookingTripRecord).totalAmount, 3200000);
    });

    test('ignores properties the contract does not define', () {
      final noisy = _booking({
        'secret': 'x',
        'actions': {..._actions(), 'debug': true},
      });

      final page = _parsePage(_page([noisy], {'traceId': 'abc'}));

      expect(page.items, hasLength(1));
    });

    test('an empty page is valid', () {
      final page = _parsePage(_page([], {'summary': null, 'totalCount': 0}));

      expect(page.items, isEmpty);
      expect(page.totalCount, 0);
    });

    group('rejects a malformed body', () {
      final cases = <String, Object? Function()>{
        'not an object': () => <Object?>[],
        'null body': () => null,
        'items not a list': () => _page([], {'items': {}}),
        'items missing': () => _page([])..remove('items'),
        'unknown kind': () => _page([
          _booking({'kind': 'serviceBooking'}),
        ]),
        'tripType not matching the kind': () => _page([
          _booking({'tripType': 'SelfPlannedItinerary'}),
        ]),
        'unknown tab': () => _page([
          _booking({'tab': 'Archived'}),
        ]),
        'booking without bookingCode': () =>
            _page([_booking()..remove('bookingCode')]),
        'booking without totalAmount': () =>
            _page([_booking()..remove('totalAmount')]),
        'itinerary without stopCount': () =>
            _page([_itinerary()..remove('stopCount')]),
        'bad date string': () => _page([
          _booking({'departureAtUtc': 'soon'}),
        ]),
        'date not a string': () => _page([
          _booking({'departureAtUtc': 17}),
        ]),
        'actions flag missing': () => _page([
          _booking({
            'actions': {
              'canReview': true,
              'canViewETicket': true,
              'ticketId': 1,
            },
          }),
        ]),
        'actions flag not a bool': () => _page([
          _booking({
            'actions': {..._actions(), 'canReview': 'yes'},
          }),
        ]),
        'ticketId zero': () => _page([
          _booking({'actions': _actions(ticketId: 0)}),
        ]),
        'ticketId fractional': () => _page([
          _booking({'actions': _actions(ticketId: 1.5)}),
        ]),
        'id zero': () => _page([
          _booking({'id': 0}),
        ]),
        'id negative': () => _page([
          _booking({'id': -3}),
        ]),
        'id a string': () => _page([
          _booking({'id': '123'}),
        ]),
        'id fractional': () => _page([
          _booking({'id': 1.5}),
        ]),
        'reviewableRecord id differs': () => _page([
          _booking({
            'reviewableRecord': {'kind': 'commerceBooking', 'id': 124},
          }),
        ]),
        'reviewableRecord of another kind': () => _page([
          _booking({
            'reviewableRecord': {'kind': 'serviceBooking', 'id': 123},
          }),
        ]),
        'booking with null reviewableRecord': () => _page([
          _booking({'reviewableRecord': null}),
        ]),
        'booking with null review': () => _page([
          _booking({'review': null}),
        ]),
        'review exists without a rating': () => _page([
          _booking({
            'review': {'exists': true, 'reviewId': 41},
          }),
        ]),
        'review rating above 5': () => _page([
          _booking({
            'review': {'exists': true, 'reviewId': 41, 'rating': 6},
          }),
        ]),
        'review rating zero': () => _page([
          _booking({
            'review': {'exists': true, 'reviewId': 41, 'rating': 0},
          }),
        ]),
        'itinerary with a reviewableRecord': () => _page([
          _itinerary({
            'reviewableRecord': {'kind': 'commerceBooking', 'id': 45},
          }),
        ]),
        'itinerary with a review': () => _page([
          _itinerary({
            'review': {'exists': false},
          }),
        ]),
        'negative totalCount': () => _page([], {'totalCount': -1}),
        'page zero': () => _page([], {'page': 0}),
        'pageSize zero': () => _page([], {'pageSize': 0}),
        'fractional totalCount': () => _page([], {'totalCount': 1.5}),
        'negative summary count': () => _page([], {
          'summary': {'totalCompletedTrips': -1, 'totalVisitedPois': 0},
        }),
        'summary missing a field': () => _page([], {
          'summary': {'totalCompletedTrips': 1},
        }),
        'negative participantCount': () => _page([
          _booking({'participantCount': -2}),
        ]),
        'visitedCount above stopCount': () => _page([
          _itinerary({'visitedCount': 7}),
        ]),
      };

      for (final entry in cases.entries) {
        test(entry.key, () {
          expect(
            () => TripRecordsJson.page(_wire(entry.value())),
            throwsFormatException,
          );
        });
      }
    });
  });

  group('TripRecordsJson.detail', () {
    Map<String, dynamic> bookingDetail([
      Map<String, dynamic> over = const {},
    ]) => {
      ..._booking(),
      'tour': {'title': 'Hoi An Lantern Tour', 'destinationSummary': 'Hoi An'},
      'schedule': {
        'startAtUtc': '2026-10-01T02:00:00+00:00',
        'endAtUtc': '2026-10-01T10:00:00+00:00',
        'meetingPoint': 'Old Town gate',
      },
      'participants': {'adult': 2, 'child': 1, 'infant': 0},
      ...over,
    };

    Map<String, dynamic> itineraryDetail([
      Map<String, dynamic> over = const {},
    ]) => {
      ..._itinerary(),
      'validFromUtc': '2026-09-19T00:00:00+00:00',
      'validToUtc': '2026-09-22T00:00:00+00:00',
      'stops': [
        {
          'sequenceNo': 1,
          'poiId': 9,
          'poiName': 'Dragon Bridge',
          'plannedArrivalUtc': '2026-09-20T01:00:00+00:00',
          'plannedDepartureUtc': '2026-09-20T02:00:00+00:00',
          'visitStatus': 'Reached',
          'reachedAtUtc': '2026-09-20T01:05:00+00:00',
        },
        {
          'sequenceNo': 2,
          'poiId': 10,
          'poiName': 'My Khe Beach',
          'plannedArrivalUtc': '2026-09-20T03:00:00+00:00',
          'plannedDepartureUtc': '2026-09-20T04:00:00+00:00',
          'visitStatus': 'Skipped',
          'skippedAtUtc': '2026-09-20T03:10:00+00:00',
        },
        {
          'sequenceNo': 3,
          'poiId': 11,
          'poiName': 'Han Market',
          'plannedArrivalUtc': null,
          'plannedDepartureUtc': null,
          'visitStatus': 'Pending',
        },
      ],
      'session': {
        'startedAtUtc': '2026-09-20T01:00:00+00:00',
        'endedAtUtc': '2026-09-20T06:00:00+00:00',
        'completionReason': 'TravelerStopped',
      },
      ...over,
    };

    test('parses a completed booking with tour, schedule and participants', () {
      final detail =
          TripRecordsJson.detail(_wire(bookingDetail())) as BookingTripDetail;

      expect(detail.record.id, 123);
      expect(detail.record.actions.ticketId, 77);
      expect(detail.tour.title, 'Hoi An Lantern Tour');
      expect(detail.tour.destinationSummary, 'Hoi An');
      expect(detail.schedule.startAtUtc, DateTime.utc(2026, 10, 1, 2));
      expect(detail.schedule.endAtUtc, DateTime.utc(2026, 10, 1, 10));
      expect(detail.schedule.meetingPoint, 'Old Town gate');
      expect(detail.participants.adult, 2);
      expect(detail.participants.child, 1);
      expect(detail.participants.infant, 0);
      expect(detail.cancellation, isNull);
      expect(detail.refund, isNull);
    });

    test('parses cancellation and a refund whose channel is null', () {
      final detail =
          TripRecordsJson.detail(
                _wire(
                  bookingDetail({
                    'tab': 'Cancelled',
                    'status': 'Cancelled',
                    'actions': _actions(
                      canReview: false,
                      canViewETicket: false,
                      ticketId: null,
                      canViewRefund: true,
                    ),
                    'schedule': {
                      'startAtUtc': '2026-10-01T02:00:00+00:00',
                      'endAtUtc': '2026-10-01T10:00:00+00:00',
                      'meetingPoint': null,
                    },
                    'cancellation': {
                      'cancelledAtUtc': '2026-08-20T00:00:00+00:00',
                      'reason': 'Change of plans',
                    },
                    'refund': {
                      'status': 'Processed',
                      'amount': 800000.00,
                      'channel': null,
                    },
                  }),
                ),
              )
              as BookingTripDetail;

      expect(detail.schedule.meetingPoint, isNull);
      expect(detail.cancellation?.cancelledAtUtc, DateTime.utc(2026, 8, 20));
      expect(detail.cancellation?.reason, 'Change of plans');
      expect(detail.refund?.status, 'Processed');
      expect(detail.refund?.amount, 800000);
      expect(detail.refund?.channel, isNull);
    });

    test('accepts a cancellation with no timestamp and no reason', () {
      final detail =
          TripRecordsJson.detail(
                _wire(
                  bookingDetail({
                    'cancellation': {'cancelledAtUtc': null, 'reason': null},
                  }),
                ),
              )
              as BookingTripDetail;

      expect(detail.cancellation?.cancelledAtUtc, isNull);
      expect(detail.cancellation?.reason, isNull);
    });

    test('parses a completed itinerary with stops, visit data and session', () {
      final detail =
          TripRecordsJson.detail(_wire(itineraryDetail()))
              as ItineraryTripDetail;

      expect(detail.validFromUtc, DateTime.utc(2026, 9, 19));
      expect(detail.validToUtc, DateTime.utc(2026, 9, 22));
      expect(detail.stops.map((s) => s.poiId), [9, 10, 11]);
      expect(detail.stops[0].poiName, 'Dragon Bridge');
      expect(detail.stops[0].visitStatus, TripVisitStatus.reached);
      expect(detail.stops[0].reachedAtUtc, DateTime.utc(2026, 9, 20, 1, 5));
      expect(detail.stops[0].skippedAtUtc, isNull);
      expect(detail.stops[1].visitStatus, TripVisitStatus.skipped);
      expect(detail.stops[1].skippedAtUtc, DateTime.utc(2026, 9, 20, 3, 10));
      expect(detail.stops[2].visitStatus, TripVisitStatus.pending);
      expect(detail.stops[2].plannedArrivalUtc, isNull);
      expect(detail.session?.startedAtUtc, DateTime.utc(2026, 9, 20, 1));
      expect(detail.session?.endedAtUtc, DateTime.utc(2026, 9, 20, 6));
      expect(detail.session?.completionReason, 'TravelerStopped');
    });

    test(
      'parses a planned itinerary: stops without visit data, no session',
      () {
        final body = {
          ..._itinerary({'tab': 'Upcoming', 'status': 'Active'}),
          'stops': [
            {
              'sequenceNo': 1,
              'poiId': 9,
              'poiName': 'Dragon Bridge',
              'plannedArrivalUtc': '2026-12-01T01:00:00+00:00',
              'plannedDepartureUtc': '2026-12-01T02:00:00+00:00',
            },
          ],
        };

        final detail =
            TripRecordsJson.detail(_wire(body)) as ItineraryTripDetail;

        expect(detail.session, isNull);
        expect(detail.validFromUtc, isNull);
        expect(detail.stops.single.visitStatus, isNull);
      },
    );

    test('accepts a session with a null end and reason', () {
      final detail =
          TripRecordsJson.detail(
                _wire(
                  itineraryDetail({
                    'session': {
                      'startedAtUtc': '2026-09-20T01:00:00+00:00',
                      'endedAtUtc': null,
                      'completionReason': null,
                    },
                  }),
                ),
              )
              as ItineraryTripDetail;

      expect(detail.session?.endedAtUtc, isNull);
      expect(detail.session?.completionReason, isNull);
    });

    group('rejects a malformed body', () {
      final cases = <String, Object? Function()>{
        'not an object': () => 'oops',
        'unknown kind': () => bookingDetail({'kind': 'serviceBooking'}),
        'booking without a tour': () => bookingDetail()..remove('tour'),
        'tour without a title': () => bookingDetail({
          'tour': {'destinationSummary': 'Hoi An'},
        }),
        'schedule with a bad date': () => bookingDetail({
          'schedule': {
            'startAtUtc': 'x',
            'endAtUtc': '2026-10-01T10:00:00+00:00',
            'meetingPoint': null,
          },
        }),
        'participants negative': () => bookingDetail({
          'participants': {'adult': -1, 'child': 0, 'infant': 0},
        }),
        'participants missing a type': () => bookingDetail({
          'participants': {'adult': 1, 'child': 0},
        }),
        'refund without an amount': () => bookingDetail({
          'refund': {'status': 'Processed', 'channel': null},
        }),
        'refund with a negative amount': () => bookingDetail({
          'refund': {'status': 'Processed', 'amount': -1, 'channel': null},
        }),
        'itinerary without stops': () => itineraryDetail()..remove('stops'),
        'stops not a list': () => itineraryDetail({'stops': {}}),
        'stop with an unknown visitStatus': () => itineraryDetail({
          'stops': [
            {
              'sequenceNo': 1,
              'poiId': 9,
              'poiName': 'A',
              'plannedArrivalUtc': null,
              'plannedDepartureUtc': null,
              'visitStatus': 'Done',
            },
          ],
        }),
        'stop with a bad poiId': () => itineraryDetail({
          'stops': [
            {
              'sequenceNo': 1,
              'poiId': 0,
              'poiName': 'A',
              'plannedArrivalUtc': null,
              'plannedDepartureUtc': null,
            },
          ],
        }),
        'stop with a bad sequenceNo': () => itineraryDetail({
          'stops': [
            {
              'sequenceNo': 0,
              'poiId': 9,
              'poiName': 'A',
              'plannedArrivalUtc': null,
              'plannedDepartureUtc': null,
            },
          ],
        }),
        'stop with a bad reachedAtUtc': () => itineraryDetail({
          'stops': [
            {
              'sequenceNo': 1,
              'poiId': 9,
              'poiName': 'A',
              'plannedArrivalUtc': null,
              'plannedDepartureUtc': null,
              'visitStatus': 'Reached',
              'reachedAtUtc': 'x',
            },
          ],
        }),
        'session without startedAtUtc': () => itineraryDetail({
          'session': {'endedAtUtc': null, 'completionReason': null},
        }),
        'itinerary whose card is invalid': () =>
            itineraryDetail({'stopCount': 'six'}),
      };

      for (final entry in cases.entries) {
        test(entry.key, () {
          expect(
            () => TripRecordsJson.detail(_wire(entry.value())),
            throwsFormatException,
          );
        });
      }
    });
  });
}
