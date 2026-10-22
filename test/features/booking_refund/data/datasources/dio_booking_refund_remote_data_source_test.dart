import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/booking_refund/data/datasources/booking_refund_remote_data_source.dart';
import 'package:trip_mate_mobile/features/booking_refund/domain/entities/booking_refund_progress.dart';

void main() {
  late DioClient client;
  late DioBookingRefundRemoteDataSource dataSource;

  setUp(() {
    client = DioClient(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
      secureStorage: _EmptySecureStorage(),
    );
    dataSource = DioBookingRefundRemoteDataSource(client);
  });

  test('requests and parses the booking refund progress contract', () async {
    final adapter = _Adapter(
      jsonEncode({
        'data': {
          'bookingId': 42,
          'bookingCode': 'BK-20261022-00042',
          'refundAmount': 500000,
          'status': 'RetryPending',
          'attemptCount': 1,
          'requestedAtUtc': '2026-10-22T01:00:00Z',
          'nextAttemptAtUtc': '2026-10-22T02:00:00Z',
        },
      }),
    );
    client.dio.httpClientAdapter = adapter;

    final progress = await dataSource.getProgress('42');

    expect(adapter.requests.single.path, '/api/v1/bookings/42/refund');
    expect(progress.status, BookingRefundStatus.retryPending);
    expect(progress.refundAmount, 500000);
  });

  test('rejects an invalid booking id without requesting the API', () async {
    final adapter = _Adapter('{}');
    client.dio.httpClientAdapter = adapter;

    await expectLater(
      dataSource.getProgress('../42'),
      throwsA(isA<FormatException>()),
    );
    expect(adapter.requests, isEmpty);
  });
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this._body);

  final String _body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      _body,
      200,
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
