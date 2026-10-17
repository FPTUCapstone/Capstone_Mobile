import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/tour_detail/data/datasources/dio_tour_detail_remote_data_source.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';

Map<String, Object?> _validBody({String tourId = '1'}) => {
  'tourId': tourId,
  'title': 'Da Nang Discovery 3D2N',
  'description': null,
  'destination': 'Da Nang',
  'destinations': ['Da Nang'],
  'durationDays': 3,
  'basePrice': 2890000,
  'currency': 'VND',
  'operator': {'name': 'Central Vietnam Travel', 'contactPhone': null},
  'images': <Object?>[],
  'inclusions': null,
  'exclusions': null,
  'cancellationPolicy': {'rules': <Object?>[]},
  'itinerary': <Object?>[],
  'schedules': [
    {
      'scheduleId': '5',
      'startAtUtc': '2026-11-06T01:00:00Z',
      'endAtUtc': '2026-11-08T10:00:00Z',
      'adultPrice': 2890000,
      'availabilityStatus': 'available',
      'remainingSlots': 4,
      'bookable': true,
    },
  ],
  'hasBookableSchedule': true,
  'rating': {'average': null, 'count': 0},
  'asOfUtc': '2026-10-17T09:00:00Z',
};

void main() {
  late DioClient client;
  late DioTourDetailRemoteDataSource dataSource;

  setUp(() {
    client = DioClient(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
      secureStorage: _EmptySecureStorage(),
    );
    dataSource = DioTourDetailRemoteDataSource(client);
  });

  test('requests the public detail endpoint without credentials', () async {
    final adapter = _Adapter(body: jsonEncode(_validBody()));
    client.dio.httpClientAdapter = adapter;

    final detail = await dataSource.getTourDetail('1');

    expect(adapter.requests, hasLength(1));
    final request = adapter.requests.single;
    expect(request.method, 'GET');
    expect(request.path, '/api/v1/tours/1');
    expect(request.extra['skipAuth'], isTrue);
    expect(detail?.tourId, '1');
    expect(
      detail?.schedules.single.availabilityStatus,
      AvailabilityStatus.available,
    );
  });

  test('keeps a very large id exact in the path', () async {
    final adapter = _Adapter(
      body: jsonEncode(_validBody(tourId: '9007199254740993')),
    );
    client.dio.httpClientAdapter = adapter;

    final detail = await dataSource.getTourDetail('9007199254740993');

    expect(adapter.requests.single.path, '/api/v1/tours/9007199254740993');
    expect(detail?.tourId, '9007199254740993');
  });

  test('404 means the tour is not available', () async {
    final adapter = _Adapter(
      body: '{"title":"Not found","code":"tour.not_found"}',
      statusCode: 404,
    );
    client.dio.httpClientAdapter = adapter;

    expect(await dataSource.getTourDetail('4'), isNull);
  });

  test('404 without a body is also not available', () async {
    client.dio.httpClientAdapter = _Adapter(body: '', statusCode: 404);

    expect(await dataSource.getTourDetail('4'), isNull);
  });

  for (final status in const [400, 401, 403, 429, 500, 502, 503]) {
    test('HTTP $status is a failure, not a missing tour', () async {
      client.dio.httpClientAdapter = _Adapter(body: '{}', statusCode: status);

      await expectLater(
        dataSource.getTourDetail('1'),
        throwsA(isA<DioException>()),
      );
    });
  }

  test('a network error is a failure', () async {
    client.dio.httpClientAdapter = _Adapter.failing();

    await expectLater(
      dataSource.getTourDetail('1'),
      throwsA(isA<DioException>()),
    );
  });

  test('a timeout is a failure', () async {
    client.dio.httpClientAdapter = _Adapter.failing(
      DioExceptionType.receiveTimeout,
    );

    await expectLater(
      dataSource.getTourDetail('1'),
      throwsA(isA<DioException>()),
    );
  });

  test('a 200 with an HTML body is rejected', () async {
    client.dio.httpClientAdapter = _Adapter(
      body: '<html><body>captive portal</body></html>',
    );

    await expectLater(dataSource.getTourDetail('1'), throwsA(anything));
  });

  test('a 200 with a JSON array is rejected', () async {
    client.dio.httpClientAdapter = _Adapter(body: '[]');

    await expectLater(
      dataSource.getTourDetail('1'),
      throwsA(isA<FormatException>()),
    );
  });

  test('a 200 with truncated JSON is rejected', () async {
    client.dio.httpClientAdapter = _Adapter(body: '{"tourId":"1","title":');

    await expectLater(dataSource.getTourDetail('1'), throwsA(anything));
  });

  test('a 200 that breaks the contract is rejected', () async {
    final body = _validBody()..['tourId'] = 1;
    client.dio.httpClientAdapter = _Adapter(body: jsonEncode(body));

    await expectLater(
      dataSource.getTourDetail('1'),
      throwsA(isA<FormatException>()),
    );
  });

  for (final id in const [
    '',
    ' ',
    'abc',
    'demo-tour-1',
    '1/2',
    '../auth',
    '1?x=y',
    '-1',
    '1.5',
    '12345678901234567890',
  ]) {
    test('id "$id" is treated as missing without calling the API', () async {
      final adapter = _Adapter(body: jsonEncode(_validBody()));
      client.dio.httpClientAdapter = adapter;

      expect(await dataSource.getTourDetail(id), isNull);
      expect(adapter.requests, isEmpty);
    });
  }
}

final class _Adapter implements HttpClientAdapter {
  _Adapter({required String body, this.statusCode = 200})
    : _body = body,
      _failure = null;

  _Adapter.failing([DioExceptionType type = DioExceptionType.connectionError])
    : _body = '',
      statusCode = 0,
      _failure = type;

  final String _body;
  final int statusCode;
  final DioExceptionType? _failure;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final failure = _failure;
    if (failure != null) {
      throw DioException(requestOptions: options, type: failure);
    }
    return ResponseBody.fromString(
      _body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _EmptySecureStorage implements SecureStorageService {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
