import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/commercial_services/data/commercial_booking_api.dart';

void main() {
  test(
    'reuses the pending key after recreating the API following a timeout',
    () async {
      final claims = base64Url.encode(utf8.encode('{"sub":"42"}'));
      final storage = _MemoryStorage()
        ..values[AppConstants.accessTokenKey] = 'header.$claims.signature';
      final adapter = _BookingAdapter();
      CommercialBookingApi api() {
        final client = DioClient(
          config: AppConfig(
            environment: Environment.production,
            apiBaseUrl: Uri.parse('https://example.test'),
          ),
          secureStorage: storage,
        );
        client.dio.httpClientAdapter = adapter;
        return CommercialBookingApi(client, storage);
      }

      final request = (
        serviceId: 9,
        startsAt: DateTime.utc(2026, 12, 1),
        quantity: 1,
        contactName: 'Traveler',
        contactPhone: '0901234567',
        contactEmail: 'example@example.test',
        specialRequest: '',
        itineraryId: null as int?,
      );
      await expectLater(
        api().submit(request, 'original-key'),
        throwsA(isA<Failure>()),
      );
      expect(
        (await api().submit(request, 'app-restarted')).requestCode,
        'SR-18',
      );
      await api().submit(request, 'intentional-new-request');
      expect(adapter.keys, [
        'original-key',
        'original-key',
        'intentional-new-request',
      ]);
    },
  );
}

final class _MemoryStorage implements SecureStorageService {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }

  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

final class _BookingAdapter implements HttpClientAdapter {
  final keys = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    keys.add(options.headers['Idempotency-Key']);
    if (keys.length == 1) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return ResponseBody.fromString(
      '{"requestCode":"SR-18","status":"PendingConfirmation","estimatedAmount":120000}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
