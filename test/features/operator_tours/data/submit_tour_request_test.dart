import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/operator_tours/data/datasources/operator_tour_remote_data_source.dart';
import 'package:trip_mate_mobile/features/operator_tours/data/repositories/operator_tour_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/entities/tour_package_draft.dart';
import 'package:trip_mate_mobile/features/operator_tours/domain/usecases/tour_package_use_cases.dart';

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
  _Adapter({this.body = '{}'});

  int status = 200;
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

void main() {
  late _Adapter adapter;
  late OperatorTourRepositoryImpl repository;
  late SubmitTourForReviewUseCase submit;
  setUp(() {
    adapter = _Adapter(
      body:
          '{"tourId":42,"status":"Pending","submittedAtUtc":"2026-11-18T10:00:00Z"}',
    );
    final client = DioClient(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('http://localhost:5003'),
      ),
      secureStorage: _Storage(),
    );
    client.dio.interceptors.clear();
    client.dio.httpClientAdapter = adapter;
    repository = OperatorTourRepositoryImpl(
      DioOperatorTourRemoteDataSource(client),
    );
    submit = SubmitTourForReviewUseCase(repository);
  });
  test('posts trimmed optional note and parses acknowledgement', () async {
    final result = await submit(42, submissionNote: '  Staff context  ');
    expect(
      adapter.requests.single.path,
      '/api/v1/operator/tours/42/submit-review',
    );
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.data, {'submissionNote': 'Staff context'});
    expect(result.tourId, 42);
    expect(result.submittedAtUtc, DateTime.utc(2026, 11, 18, 10));
  });
  test('empty note uses backward compatible no-body request', () async {
    adapter.body = '{"tourId":42,"status":"Pending"}';
    expect((await submit(42, submissionNote: '  ')).submittedAtUtc, isNull);
    expect(adapter.requests.single.data, isNull);
  });
  test('UTF16 boundary accepts 4000 and rejects 4002 before HTTP', () async {
    await submit(42, submissionNote: '\u{1F600}' * 2000);
    await expectLater(
      () => submit(42, submissionNote: '\u{1F600}' * 2001),
      throwsA(isA<ValidationFailure>()),
    );
    expect(adapter.requests, hasLength(1));
  });
  test('connection failure is safe and human readable', () async {
    adapter.error = (options) => DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'secret_exception',
    );
    await expectLater(
      () => submit(42),
      throwsA(
        isA<NetworkFailure>().having(
          (failure) => failure.message,
          'message',
          'Vui lòng kiểm tra kết nối mạng.',
        ),
      ),
    );
  });
  for (final status in [400, 401, 403, 404, 409, 422, 500]) {
    test('HTTP $status never displays server internals', () async {
      adapter.status = status;
      adapter.body =
          '{"errors":{"submissionNote":["SQL secret_exception"]},"detail":"secret_exception"}';
      try {
        await submit(42);
        fail('Expected failure');
      } on Failure catch (error) {
        expect(error.message, isNot(contains('secret_exception')));
        expect(error.message, isNot(contains('SQL')));
      }
    });
  }

  test('reopen departure sends Idempotency-Key and parses response', () async {
    adapter.status = 201;
    adapter.body =
        '{"tourId":42,"scheduleId":88,"status":"Scheduled","startAtUtc":"2027-07-01T01:00:00Z","endAtUtc":"2027-07-02T09:00:00Z","meetingPoint":"Airport","minimumCapacity":2,"totalCapacity":20,"reservedCapacity":0,"adultPrice":2500000,"meetingLatitude":16.05,"meetingLongitude":108.20}';
    final addDeparture = AddTourDepartureUseCase(repository);
    final added = await addDeparture(
      42,
      TourScheduleDraft(
        startAtUtc: DateTime.utc(2027, 7, 1, 1),
        endAtUtc: DateTime.utc(2027, 7, 2, 9),
        totalCapacity: 20,
        minimumCapacity: 2,
        adultPrice: 2500000,
        meetingPoint: 'Airport',
        meetingLatitude: 16.05,
        meetingLongitude: 108.20,
      ),
      'idem-dep-1',
    );
    expect(
      adapter.requests.single.path,
      '/api/v1/operator/tours/42/departures',
    );
    expect(adapter.requests.single.headers['Idempotency-Key'], 'idem-dep-1');
    expect(added.id, 88);
    expect(added.meetingPoint, 'Airport');
  });

  test('maps departure_itinerary_mismatch 422 cleanly', () async {
    adapter.status = 422;
    adapter.body =
        '{"extensions":{"errorCode":"operator_tour.departure_itinerary_mismatch"}}';
    final addDeparture = AddTourDepartureUseCase(repository);
    await expectLater(
      () => addDeparture(
        42,
        TourScheduleDraft(
          startAtUtc: DateTime.utc(2027, 7, 1, 1),
          endAtUtc: DateTime.utc(2027, 7, 2, 9),
          totalCapacity: 20,
        ),
        'idem-dep-2',
      ),
      throwsA(
        isA<ConstraintFailure>().having(
          (f) => f.message,
          'message',
          contains('thời gian tham quan dự kiến'),
        ),
      ),
    );
  });

  test('deleteTour calls DELETE endpoint', () async {
    adapter.status = 204;
    adapter.body = '';
    await DeleteTourPackageUseCase(repository)(42);
    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/api/v1/operator/tours/42');
  });
}
