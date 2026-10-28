import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/trip_history/data/repositories/trip_records_repository_impl.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/repositories/trip_records_repository.dart';

final class _Storage implements SecureStorageService {
  @override
  Future<String?> read(String key) async => 'token';
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
}

final class _Adapter implements HttpClientAdapter {
  _Adapter({this.status = 200, this.body = '{}', this.error});

  int status;
  String body;
  DioException Function(RequestOptions options)? error;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final failure = error;
    if (failure != null) throw failure(options);
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _bookingJson({int id = 123}) => {
  'kind': 'commerceBooking',
  'id': id,
  'tripType': 'TourBooking',
  'tab': 'Completed',
  'title': 'Hoi An Lantern Tour',
  'departureAtUtc': '2026-10-01T02:00:00+00:00',
  'status': 'Completed',
  'bookingCode': 'TM-000123',
  'participantCount': 2,
  'totalAmount': 3200000.00,
  'reviewableRecord': {'kind': 'commerceBooking', 'id': id},
  'actions': {
    'canReview': true,
    'canViewETicket': true,
    'ticketId': 77,
    'canViewRefund': false,
  },
  'review': {'exists': false},
};

Map<String, dynamic> _itineraryJson({int id = 45}) => {
  'kind': 'itinerary',
  'id': id,
  'tripType': 'SelfPlannedItinerary',
  'tab': 'Completed',
  'title': 'Da Nang 2 days',
  'departureAtUtc': '2026-09-20T01:00:00+00:00',
  'status': 'Completed',
  'stopCount': 1,
  'visitedCount': 1,
  'reviewableRecord': null,
  'actions': {
    'canReview': false,
    'canViewETicket': false,
    'ticketId': null,
    'canViewRefund': false,
  },
  'review': null,
  'stops': [
    {
      'sequenceNo': 1,
      'poiId': 9,
      'poiName': 'Dragon Bridge',
      'plannedArrivalUtc': null,
      'plannedDepartureUtc': null,
      'visitStatus': 'Reached',
      'reachedAtUtc': '2026-09-20T01:05:00+00:00',
    },
  ],
};

String _pageBody([List<Map<String, dynamic>>? items]) => jsonEncode({
  'items': items ?? [_bookingJson()],
  'summary': {'totalCompletedTrips': 1, 'totalVisitedPois': 0},
  'page': 1,
  'pageSize': 20,
  'totalCount': 1,
});

({TripRecordsRepositoryImpl repository, _Adapter adapter}) _build(
  _Adapter adapter,
) {
  final client = DioClient(
    config: AppConfig(
      environment: Environment.development,
      apiBaseUrl: Uri.parse('http://10.0.2.2:5000'),
    ),
    secureStorage: _Storage(),
  );
  // Without the auth interceptor a 401 never starts a real token refresh.
  client.dio.interceptors.clear();
  client.dio.httpClientAdapter = adapter;
  return (repository: TripRecordsRepositoryImpl(client), adapter: adapter);
}

DioException _connection(RequestOptions options, DioExceptionType type) =>
    DioException(requestOptions: options, type: type, message: 'secret detail');

TripRecordsQuery _query({
  TripStatus tab = TripStatus.completed,
  TripRecordTypeFilter tripType = TripRecordTypeFilter.all,
  DateTime? startDate,
  DateTime? endDate,
  int page = 1,
}) => TripRecordsQuery(
  tab: tab,
  tripType: tripType,
  startDate: startDate,
  endDate: endDate,
  page: page,
);

void main() {
  group('getPage request', () {
    test(
      'asks for the tab and page with the canonical page size only',
      () async {
        final built = _build(_Adapter(body: _pageBody()));

        await built.repository.getPage(
          _query(tab: TripStatus.cancelled, page: 3),
        );

        final request = built.adapter.requests.single;
        expect(request.method, 'GET');
        expect(request.uri.path, '/api/v1/traveler/trips');
        expect(request.uri.queryParameters, {
          'tab': 'Cancelled',
          'page': '3',
          'pageSize': '20',
        });
      },
    );

    test('sends each tab by its wire name', () async {
      for (final entry in {
        TripStatus.upcoming: 'Upcoming',
        TripStatus.completed: 'Completed',
        TripStatus.cancelled: 'Cancelled',
      }.entries) {
        final built = _build(_Adapter(body: _pageBody()));
        await built.repository.getPage(_query(tab: entry.key));
        expect(
          built.adapter.requests.single.uri.queryParameters['tab'],
          entry.value,
        );
      }
    });

    test(
      'omits tripType for All and sends the other two by wire name',
      () async {
        final all = _build(_Adapter(body: _pageBody()));
        await all.repository.getPage(_query());
        expect(
          all.adapter.requests.single.uri.queryParameters.containsKey(
            'tripType',
          ),
          isFalse,
        );

        final tours = _build(_Adapter(body: _pageBody()));
        await tours.repository.getPage(
          _query(tripType: TripRecordTypeFilter.tourBooking),
        );
        expect(
          tours.adapter.requests.single.uri.queryParameters['tripType'],
          'TourBooking',
        );

        final itineraries = _build(_Adapter(body: _pageBody()));
        await itineraries.repository.getPage(
          _query(tripType: TripRecordTypeFilter.selfPlannedItinerary),
        );
        expect(
          itineraries.adapter.requests.single.uri.queryParameters['tripType'],
          'SelfPlannedItinerary',
        );
      },
    );

    test(
      'sends the date range as calendar days, and omits an unset end',
      () async {
        final both = _build(_Adapter(body: _pageBody()));
        await both.repository.getPage(
          _query(
            startDate: DateTime.utc(2026, 10, 1),
            endDate: DateTime.utc(2026, 10, 31),
          ),
        );
        expect(
          both.adapter.requests.single.uri.queryParameters['fromDate'],
          '2026-10-01',
        );
        expect(
          both.adapter.requests.single.uri.queryParameters['toDate'],
          '2026-10-31',
        );

        final start = _build(_Adapter(body: _pageBody()));
        await start.repository.getPage(
          _query(startDate: DateTime.utc(2026, 1, 5)),
        );
        expect(
          start.adapter.requests.single.uri.queryParameters['fromDate'],
          '2026-01-05',
        );
        expect(
          start.adapter.requests.single.uri.queryParameters.containsKey(
            'toDate',
          ),
          isFalse,
        );
      },
    );

    test('never sends a search or legacy status parameter', () async {
      final built = _build(_Adapter(body: _pageBody()));

      await built.repository.getPage(_query());

      final keys = built.adapter.requests.single.uri.queryParameters.keys;
      expect(keys, isNot(contains('status')));
      expect(keys, isNot(contains('query')));
    });
  });

  group('getPage result', () {
    test('parses the page into domain entities', () async {
      final built = _build(
        _Adapter(body: _pageBody([_bookingJson(), _itineraryJson()])),
      );

      final page = await built.repository.getPage(_query());

      expect(page.items, hasLength(2));
      expect(page.items.first, isA<BookingTripRecord>());
      expect((page.items.first as BookingTripRecord).totalAmount, 3200000);
      expect(page.items.last, isA<ItineraryTripRecord>());
      expect(page.summary?.totalCompletedTrips, 1);
      expect(page.totalCount, 1);
    });

    test(
      'a malformed 200 body is an invalid-response server failure',
      () async {
        for (final body in [
          '{"items":"nope","page":1,"pageSize":20,"totalCount":0}',
          'not json',
          '[]',
          'null',
        ]) {
          final built = _build(_Adapter(body: body));

          await expectLater(
            built.repository.getPage(_query()),
            throwsA(
              isA<ServerFailure>().having(
                (f) => f.message,
                'message',
                'trip_history.invalid_response',
              ),
            ),
          );
        }
      },
    );
  });

  group('getDetail', () {
    test('requests the (kind, id) path and parses the detail', () async {
      final built = _build(_Adapter(body: jsonEncode(_itineraryJson(id: 45))));

      final detail = await built.repository.getDetail(
        TripRecordKind.itinerary,
        45,
      );

      expect(
        built.adapter.requests.single.uri.path,
        '/api/v1/traveler/trips/itinerary/45',
      );
      expect(detail, isA<ItineraryTripDetail>());
      expect(
        (detail as ItineraryTripDetail).stops.single.poiName,
        'Dragon Bridge',
      );
    });

    test('uses the commerceBooking wire kind in the path', () async {
      final body = {
        ..._bookingJson(),
        'tour': {'title': 'T', 'destinationSummary': 'D'},
        'schedule': {
          'startAtUtc': '2026-10-01T02:00:00+00:00',
          'endAtUtc': '2026-10-01T10:00:00+00:00',
          'meetingPoint': null,
        },
        'participants': {'adult': 2, 'child': 0, 'infant': 0},
      };
      final built = _build(_Adapter(body: jsonEncode(body)));

      await built.repository.getDetail(TripRecordKind.commerceBooking, 123);

      expect(
        built.adapter.requests.single.uri.path,
        '/api/v1/traveler/trips/commerceBooking/123',
      );
    });

    test(
      'rejects an answer for another record than the one requested',
      () async {
        final built = _build(
          _Adapter(body: jsonEncode(_itineraryJson(id: 46))),
        );

        await expectLater(
          built.repository.getDetail(TripRecordKind.itinerary, 45),
          throwsA(
            isA<ServerFailure>().having(
              (f) => f.message,
              'message',
              'trip_history.invalid_response',
            ),
          ),
        );
      },
    );

    test('rejects an answer of another kind than the one requested', () async {
      final built = _build(_Adapter(body: jsonEncode(_bookingJson(id: 45))));

      await expectLater(
        built.repository.getDetail(TripRecordKind.itinerary, 45),
        throwsA(isA<ServerFailure>()),
      );
    });

    test(
      'a malformed detail body is an invalid-response server failure',
      () async {
        final built = _build(
          _Adapter(body: jsonEncode({'kind': 'itinerary', 'id': 45})),
        );

        await expectLater(
          built.repository.getDetail(TripRecordKind.itinerary, 45),
          throwsA(isA<ServerFailure>()),
        );
      },
    );
  });

  group('failure mapping', () {
    final cases = <String, ({int status, String body, Matcher matcher})>{
      '401': (
        status: 401,
        body: '{"errorCode":"UNAUTHENTICATED"}',
        matcher: isA<AuthenticationFailure>(),
      ),
      '403': (
        status: 403,
        body: '{"errorCode":"trip_history.forbidden"}',
        matcher: isA<PermissionFailure>(),
      ),
      '404': (
        status: 404,
        body: '{"errorCode":"trip_history.record_not_found"}',
        matcher: isA<NotFoundFailure>(),
      ),
      '400 invalid_date_range': (
        status: 400,
        body:
            '{"errorCode":"trip_history.invalid_date_range","detail":"SELECT * FROM x"}',
        matcher: isA<ValidationFailure>().having(
          (f) => f.message,
          'message',
          'trip_history.invalid_date_range',
        ),
      ),
      '400 invalid_paging': (
        status: 400,
        body: '{"errorCode":"trip_history.invalid_paging"}',
        matcher: isA<ServerFailure>(),
      ),
      '400 invalid_tab': (
        status: 400,
        body: '{"errorCode":"trip_history.invalid_tab"}',
        matcher: isA<ServerFailure>(),
      ),
      '500 with a leaking body': (
        status: 500,
        body: '{"title":"SELECT * FROM secrets","errorCode":"internal.boom"}',
        matcher: isA<ServerFailure>(),
      ),
      '503 html': (
        status: 503,
        body: '<html>Bad gateway</html>',
        matcher: isA<ServerFailure>(),
      ),
    };

    for (final entry in cases.entries) {
      test('${entry.key} on the list', () async {
        final built = _build(
          _Adapter(status: entry.value.status, body: entry.value.body),
        );

        await expectLater(
          built.repository.getPage(_query()),
          throwsA(entry.value.matcher),
        );
      });

      test('${entry.key} on the detail', () async {
        final built = _build(
          _Adapter(status: entry.value.status, body: entry.value.body),
        );

        await expectLater(
          built.repository.getDetail(TripRecordKind.itinerary, 45),
          throwsA(entry.value.matcher),
        );
      });
    }

    test(
      'no failure message exposes a server body or an exception text',
      () async {
        for (final entry in cases.entries) {
          final built = _build(
            _Adapter(status: entry.value.status, body: entry.value.body),
          );
          final failure = await built.repository
              .getPage(_query())
              .then<Failure?>((_) => null)
              .catchError((Object e) => e as Failure);

          expect(failure, isNotNull, reason: entry.key);
          expect(
            failure!.message,
            isNot(contains('SELECT')),
            reason: entry.key,
          );
          expect(
            failure.message,
            isNot(contains('Bad gateway')),
            reason: entry.key,
          );
          expect(
            failure.message,
            isNot(contains('internal.boom')),
            reason: entry.key,
          );
          expect(
            failure.message,
            isNot(contains('DioException')),
            reason: entry.key,
          );
        }
      },
    );

    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ]) {
      test(
        '${type.name} is a network failure with no exception text',
        () async {
          final built = _build(
            _Adapter(error: (options) => _connection(options, type)),
          );

          await expectLater(
            built.repository.getPage(_query()),
            throwsA(
              isA<NetworkFailure>().having(
                (f) => f.message,
                'message',
                isNot(contains('secret')),
              ),
            ),
          );
        },
      );
    }

    test(
      'an unexpected error becomes a server failure, never a raw exception',
      () async {
        final built = _build(
          _Adapter(
            error: (options) => DioException(
              requestOptions: options,
              type: DioExceptionType.unknown,
              error: StateError('boom'),
            ),
          ),
        );

        await expectLater(
          built.repository.getPage(_query()),
          throwsA(
            isA<ServerFailure>().having(
              (f) => f.message,
              'message',
              isNot(contains('boom')),
            ),
          ),
        );
      },
    );
  });
}
