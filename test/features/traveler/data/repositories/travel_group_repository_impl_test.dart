import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/travel_group_repository_impl.dart';

final class _FakeSecureStorageService implements SecureStorageService {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _storage.clear();
  }
}

void main() {
  late DioClient dioClient;
  late TravelGroupRepositoryImpl repository;
  late _FakeSecureStorageService storage;
  late RequestOptions capturedRequest;

  setUp(() {
    storage = _FakeSecureStorageService();
    dioClient = DioClient(
      config: AppConfig.fromEnvironment(),
      secureStorage: storage,
    );

    // Intercept with an HttpClientAdapter to inspect the outgoing transport request
    dioClient.dio.httpClientAdapter = _MockAdapter((options) {
      capturedRequest = options;
      return ResponseBody.fromString(
        jsonEncode({
          'groupId': 42,
          'groupName': 'Da Nang Trip',
          'itineraryId': 10,
        }),
        201,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    repository = TravelGroupRepositoryImpl(dioClient: dioClient);
  });

  test(
    'createTravelGroup sends the generated UUID in the Idempotency-Key header',
    () async {
      const testUuid = 'b3f5c71d-84e9-4e2a-92b1-9f2cb424a682';

      final result = await repository.createTravelGroup(
        name: 'Da Nang Trip',
        itineraryId: 10,
        idempotencyKey: testUuid,
      );

      expect(result.id, 42);
      expect(result.name, 'Da Nang Trip');

      expect(capturedRequest.path, '/api/v1/travel-groups');
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.data, {
        'groupName': 'Da Nang Trip',
        'itineraryId': 10,
      });

      // Transport assertion: Idempotency-Key header must be sent with the exact UUID
      expect(capturedRequest.headers['Idempotency-Key'], testUuid);
      // Verify UUID format (8-4-4-4-12 hex digits)
      final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      expect(
        uuidRegex.hasMatch(capturedRequest.headers['Idempotency-Key']),
        isTrue,
      );
    },
  );
}

final class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._handler);

  final ResponseBody Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
