import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/group_location_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/group_location.dart';

void main() {
  test(
    'maps persisted opt-in and sends member GPS to scoped endpoint',
    () async {
      final dioClient = DioClient(
        config: AppConfig(
          environment: Environment.development,
          apiBaseUrl: Uri.parse('https://api.test.invalid'),
        ),
        secureStorage: _MemorySecureStorage(),
      );
      final adapter = _RecordingAdapter();
      dioClient.dio.httpClientAdapter = adapter;
      final repository = GroupLocationRepositoryImpl(dioClient: dioClient);

      final setting = await repository.getSetting(42);
      final enabledGroups = await repository.getEnabledGroupIds();
      await repository.publish(
        42,
        const DeviceGroupLocation(latitude: 16.047079, longitude: 108.206230),
        '638947008000000000',
      );

      expect(setting.enabled, true);
      expect(setting.sessionVersion, '638947008000000000');
      expect(enabledGroups, [42]);
      expect(
        adapter.requests[1].path,
        '/api/v1/travel-groups/location-sharing/active',
      );
      expect(
        adapter.requests.first.path,
        '/api/v1/travel-groups/42/location-sharing',
      );
      expect(adapter.requests.last.path, '/api/v1/travel-groups/42/location');
      expect(adapter.requests.last.data, {
        'latitude': 16.047079,
        'longitude': 108.206230,
        'sessionVersion': '638947008000000000',
      });
    },
  );
}

final class _MemorySecureStorage implements SecureStorageService {
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

final class _RecordingAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      options.method == 'GET'
          ? options.path.endsWith('/active')
                ? '{"groupIds":[42]}'
                : '{"groupId":42,"enabled":true,"updatedAtUtc":"2026-09-29T12:00:00Z","sessionVersion":"638947008000000000"}'
          : '{"userId":7,"latitude":16.047079,"longitude":108.206230,"recordedAtUtc":"2026-09-29T12:00:01Z"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
