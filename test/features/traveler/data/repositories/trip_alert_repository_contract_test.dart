import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/navigation_session_repository_impl.dart';

void main() {
  late DioClient client;
  late NavigationSessionRepositoryImpl repository;
  late _Adapter adapter;

  setUp(() {
    client = DioClient(
      config: AppConfig(
        environment: Environment.production,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
      secureStorage: const _Storage(),
    );
    adapter = _Adapter();
    client.dio.httpClientAdapter = adapter;
    repository = NavigationSessionRepositoryImpl(dioClient: client);
  });

  test(
    'list, acknowledge, advisory and deviation use the Backend contract',
    () async {
      adapter.body = [_alertJson()];
      final alerts = await repository.listAlerts(501);
      expect(alerts.single.id, '42');
      expect(adapter.request?.path, '/api/v1/navigation-sessions/501/alerts');

      adapter
        ..body = null
        ..statusCode = 204;
      await repository.acknowledgeAlert(sessionId: 501, incidentId: 42);
      expect(
        adapter.request?.path,
        '/api/v1/navigation-sessions/501/alerts/42/acknowledgement',
      );

      adapter
        ..body = [_advisoryJson()]
        ..statusCode = 200;
      final advisories = await repository.listWeatherAdvisories(501);
      expect(advisories.single.rainMmPerHour, 4.5);

      adapter.body = _alertJson();
      await repository.reportDeviation(
        sessionId: 501,
        eventId: '116944f4-d18c-4fdd-9f42-bdf045e47e95',
        observedAtUtc: DateTime.utc(2026, 10, 23, 2, 31),
        targetItemId: 7,
      );
      expect(adapter.request?.method, 'POST');
      expect(
        adapter.request?.path,
        '/api/v1/navigation-sessions/501/deviations',
      );
      expect(adapter.request?.data, {
        'eventId': '116944f4-d18c-4fdd-9f42-bdf045e47e95',
        'observedAtUtc': '2026-10-23T02:31:00.000Z',
        'targetItemId': 7,
      });
    },
  );
}

Map<String, dynamic> _alertJson() => {
  'incidentId': 42,
  'type': 'RouteDeviation',
  'severity': 'Warning',
  'messageCode': 'trip_alert.route_deviation',
  'description': null,
  'affectedItem': {
    'itemId': 7,
    'poiId': 11,
    'name': 'Museum',
    'plannedArrivalUtc': '2026-10-23T02:00:00Z',
  },
  'detectedAtUtc': '2026-10-23T02:31:00Z',
  'resolvedAtUtc': null,
  'isRead': false,
  'reroutingProposalId': null,
};

Map<String, dynamic> _advisoryJson() => {
  'advisoryKey': 'rain:7',
  'severity': 'Info',
  'messageCode': 'trip_alert.weather_advisory',
  'itemId': 7,
  'poiId': 11,
  'poiName': 'Museum',
  'plannedArrivalUtc': '2026-10-23T02:00:00Z',
  'forecastAtUtc': '2026-10-23T02:15:00Z',
  'rainMmPerHour': 4.5,
  'condition': 'moderate rain',
};

final class _Adapter implements HttpClientAdapter {
  Object? body;
  int statusCode = 200;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _Storage implements SecureStorageService {
  const _Storage();
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}
