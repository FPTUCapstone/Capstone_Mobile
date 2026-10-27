import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/in_app_notification_repository_impl.dart';

void main() {
  test(
    'loads recipient inbox with cursor and maps the removal notice',
    () async {
      final client = _client();
      final adapter = _Adapter(
        body:
            '{"items":[{"id":42,"type":"TravelGroupMemberRemoved",'
            '"title":"Removed from group","body":"Da Nang Weekend",'
            '"relatedEntityType":"TravelGroup","relatedEntityId":9,'
            '"createdAtUtc":"2026-10-27T10:00:00Z","isRead":false}],'
            '"nextBeforeId":42}',
      );
      client.dio.httpClientAdapter = adapter;
      final repository = InAppNotificationRepositoryImpl(dioClient: client);

      final page = await repository.getInbox(
        unreadOnly: true,
        limit: 20,
        beforeId: 50,
      );

      expect(adapter.request?.path, '/api/v1/notifications');
      expect(adapter.request?.queryParameters, {
        'unreadOnly': true,
        'limit': 20,
        'beforeId': 50,
      });
      expect(page.items.single.body, 'Da Nang Weekend');
      expect(page.items.single.createdAtUtc, DateTime.utc(2026, 10, 27, 10));
      expect(page.nextBeforeId, 42);
    },
  );

  test('mark read uses recipient-free POST and accepts 204', () async {
    final client = _client();
    final adapter = _Adapter(statusCode: 204, body: '');
    client.dio.httpClientAdapter = adapter;
    final repository = InAppNotificationRepositoryImpl(dioClient: client);

    await repository.markRead(42);

    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.path, '/api/v1/notifications/42/read');
    expect(adapter.request?.queryParameters, isEmpty);
    expect(adapter.request?.data, isNull);
  });

  test('mark read does not accept an unexpected success status', () async {
    final client = _client();
    client.dio.httpClientAdapter = _Adapter(statusCode: 200, body: '{}');
    final repository = InAppNotificationRepositoryImpl(dioClient: client);
    await expectLater(repository.markRead(42), throwsA(isA<UnknownFailure>()));
  });

  test('maps 401 and inaccessible 404 to safe failures', () async {
    final client = _client();
    final repository = InAppNotificationRepositoryImpl(dioClient: client);
    client.dio.httpClientAdapter = _Adapter(statusCode: 401, body: '{}');
    await expectLater(
      repository.getInbox(),
      throwsA(isA<AuthenticationFailure>()),
    );
    client.dio.httpClientAdapter = _Adapter(statusCode: 404, body: '{}');
    await expectLater(repository.markRead(42), throwsA(isA<NotFoundFailure>()));
  });
}

DioClient _client() => DioClient(
  config: AppConfig(
    environment: Environment.production,
    apiBaseUrl: Uri.parse('https://api.test.invalid'),
  ),
  secureStorage: const _EmptyStorage(),
);

final class _Adapter implements HttpClientAdapter {
  _Adapter({required this.body, this.statusCode = 200});

  final String body;
  final int statusCode;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _EmptyStorage implements SecureStorageService {
  const _EmptyStorage();

  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}
