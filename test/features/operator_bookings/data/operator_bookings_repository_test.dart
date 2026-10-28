import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/repositories/operator_bookings_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';

import '../operator_bookings_fixtures.dart';

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

({OperatorBookingsRepositoryImpl repository, _Adapter adapter}) _build(
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
  return (repository: OperatorBookingsRepositoryImpl(client), adapter: adapter);
}

DioException _connection(RequestOptions options, DioExceptionType type) =>
    DioException(requestOptions: options, type: type, message: 'secret detail');

void main() {
  group('getPage', () {
    test(
      'requests the list endpoint with the default paging and parses the body',
      () async {
        final (:repository, :adapter) = _build(
          _Adapter(body: jsonEncode(listPageJson())),
        );

        final page = await repository.getPage(const OperatorBookingsQuery());

        expect(adapter.requests.single.method, 'GET');
        expect(adapter.requests.single.path, '/api/v1/operator/bookings');
        expect(adapter.requests.single.queryParameters, {
          'pageNumber': '1',
          'pageSize': '20',
        });
        expect(page.items.single.bookingCode, 'BK-20261020-0007');
        expect(page.summary.totalParticipants, 112);
        expect(page.totalPages, 2);
      },
    );

    test('maps every filter exactly', () async {
      final (:repository, :adapter) = _build(
        _Adapter(body: jsonEncode(listPageJson())),
      );

      await repository.getPage(
        OperatorBookingsQuery(
          tourId: '101',
          status: OperatorBookingStatus.expired,
          departureFrom: DateTime.utc(2026, 11, 1),
          departureTo: DateTime.utc(2026, 11, 30),
          keyword: '  alice  ',
          page: 3,
          pageSize: 20,
        ),
      );

      expect(adapter.requests.single.queryParameters, {
        'tourId': '101',
        'status': 'Expired',
        'departureFrom': '2026-11-01',
        'departureTo': '2026-11-30',
        'keyword': 'alice',
        'pageNumber': '3',
        'pageSize': '20',
      });
    });

    test('omits a blank keyword and unset filters', () async {
      final (:repository, :adapter) = _build(
        _Adapter(body: jsonEncode(listPageJson())),
      );

      await repository.getPage(const OperatorBookingsQuery(keyword: '   '));

      expect(
        adapter.requests.single.queryParameters.keys,
        unorderedEquals(['pageNumber', 'pageSize']),
      );
    });

    test('pads a single-digit month and day', () async {
      final (:repository, :adapter) = _build(
        _Adapter(body: jsonEncode(listPageJson())),
      );

      await repository.getPage(
        OperatorBookingsQuery(departureFrom: DateTime.utc(2026, 3, 5)),
      );

      expect(
        adapter.requests.single.queryParameters['departureFrom'],
        '2026-03-05',
      );
    });

    test(
      'a malformed body is a safe invalid-response failure, never a default-filled page',
      () async {
        final broken = listPageJson();
        (broken['items']! as List<Object?>).first! as Map<String, Object?>;
        ((broken['items']! as List<Object?>).first!
                as Map<String, Object?>)['status'] =
            'Teleporting';
        final (:repository, adapter: _) = _build(
          _Adapter(body: jsonEncode(broken)),
        );

        expect(
          repository.getPage(const OperatorBookingsQuery()),
          throwsA(
            isA<ServerFailure>().having(
              (failure) => failure.message,
              'message',
              'operator_booking.invalid_response',
            ),
          ),
        );
      },
    );

    test('a body that is not JSON is the same safe failure', () async {
      final (:repository, adapter: _) = _build(_Adapter(body: '<html>'));

      expect(
        repository.getPage(const OperatorBookingsQuery()),
        throwsA(isA<ServerFailure>()),
      );
    });

    final failures = <(String, int, String, Matcher)>[
      (
        '401',
        401,
        '{"errorCode":"UNAUTHENTICATED"}',
        isA<AuthenticationFailure>(),
      ),
      (
        '403 access required',
        403,
        '{"errorCode":"operator_tour.access_required"}',
        isA<PermissionFailure>(),
      ),
      (
        '403 forbidden',
        403,
        '{"errorCode":"operator_booking.forbidden"}',
        isA<PermissionFailure>(),
      ),
      (
        '404',
        404,
        '{"errorCode":"operator_booking.not_found"}',
        isA<NotFoundFailure>(),
      ),
      (
        '400 invalid_filter',
        400,
        '{"errorCode":"operator_booking.invalid_filter"}',
        isA<ServerFailure>(),
      ),
      (
        '500',
        500,
        '{"title":"boom","detail":"stack trace"}',
        isA<ServerFailure>(),
      ),
      ('503', 503, '{"errorCode":"MSG127"}', isA<ServerFailure>()),
    ];
    for (final (label, status, body, matcher) in failures) {
      test('maps $label without leaking server text', () async {
        final (:repository, adapter: _) = _build(
          _Adapter(status: status, body: body),
        );

        await expectLater(
          repository.getPage(const OperatorBookingsQuery()),
          throwsA(
            allOf(
              matcher,
              isA<Failure>().having(
                (failure) => failure.message,
                'message',
                isNot(anyOf(contains('stack trace'), contains('boom'))),
              ),
            ),
          ),
        );
      });
    }

    test(
      '400 invalid_date_range is a validation failure carrying the code',
      () async {
        final (:repository, adapter: _) = _build(
          _Adapter(
            status: 400,
            body: '{"errorCode":"operator_booking.invalid_date_range"}',
          ),
        );

        expect(
          repository.getPage(const OperatorBookingsQuery()),
          throwsA(
            isA<ValidationFailure>().having(
              (failure) => failure.message,
              'message',
              'operator_booking.invalid_date_range',
            ),
          ),
        );
      },
    );

    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ]) {
      test('a $type is a network failure without the raw message', () async {
        final (:repository, adapter: _) = _build(
          _Adapter(error: (options) => _connection(options, type)),
        );

        await expectLater(
          repository.getPage(const OperatorBookingsQuery()),
          throwsA(
            allOf(
              isA<NetworkFailure>(),
              isA<Failure>().having(
                (failure) => failure.message,
                'message',
                isNot(contains('secret')),
              ),
            ),
          ),
        );
      });
    }
  });

  group('getDetail', () {
    test('requests the detail endpoint and parses the body', () async {
      final (:repository, :adapter) = _build(
        _Adapter(body: jsonEncode(detailJson())),
      );

      final detail = await repository.getDetail('1201');

      expect(adapter.requests.single.path, '/api/v1/operator/bookings/1201');
      expect(adapter.requests.single.queryParameters, isEmpty);
      expect(detail.bookingId, '1201');
      expect(detail.booker.phoneNumber, '+84901234567');
    });

    test(
      'rejects a detail for another booking than the one asked for',
      () async {
        final (:repository, adapter: _) = _build(
          _Adapter(body: jsonEncode(detailJson(id: '999'))),
        );

        expect(
          repository.getDetail('1201'),
          throwsA(
            isA<ServerFailure>().having(
              (failure) => failure.message,
              'message',
              'operator_booking.invalid_response',
            ),
          ),
        );
      },
    );

    for (final id in [
      'abc',
      '12a',
      '../payouts',
      '1/refund',
      '',
      '-1',
      '1.5',
      ' 7',
    ]) {
      test('does not call the backend for the id "$id"', () async {
        final (:repository, :adapter) = _build(_Adapter());

        await expectLater(
          repository.getDetail(id),
          throwsA(isA<NotFoundFailure>()),
        );
        expect(adapter.requests, isEmpty);
      });
    }

    test('maps 403 and 404 and a malformed body', () async {
      for (final (status, matcher) in <(int, Matcher)>[
        (403, isA<PermissionFailure>()),
        (404, isA<NotFoundFailure>()),
        (401, isA<AuthenticationFailure>()),
      ]) {
        final (:repository, adapter: _) = _build(_Adapter(status: status));
        await expectLater(repository.getDetail('1201'), throwsA(matcher));
      }
      final (:repository, adapter: _) = _build(
        _Adapter(body: '{"bookingId":"1201"}'),
      );
      await expectLater(
        repository.getDetail('1201'),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  group('getTourOptions', () {
    test(
      'reads the owned tours from the revenue endpoint and keeps id and title',
      () async {
        final (:repository, :adapter) = _build(
          _Adapter(body: jsonEncode(tourOptionsJson())),
        );

        final options = await repository.getTourOptions();

        expect(adapter.requests.single.path, '/api/v1/operator/revenue/tours');
        expect(options.map((option) => option.id), ['101', '55']);
        expect(options.first.title, 'Ba Na Hills full-day tour');
      },
    );

    test(
      'a malformed list is a safe failure and a 403 is a permission failure',
      () async {
        final (:repository, adapter: _) = _build(
          _Adapter(body: '{"tours":[]}'),
        );
        await expectLater(
          repository.getTourOptions(),
          throwsA(isA<ServerFailure>()),
        );

        final (repository: denied, adapter: _) = _build(_Adapter(status: 403));
        await expectLater(
          denied.getTourOptions(),
          throwsA(isA<PermissionFailure>()),
        );
      },
    );
  });
}
