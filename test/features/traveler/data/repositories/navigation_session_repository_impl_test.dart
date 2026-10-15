import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/navigation_session_repository_impl.dart';

import '../models/navigation_session_model_test.dart';

void main() {
  late DioClient dioClient;
  late NavigationSessionRepositoryImpl repository;

  _RecordingHttpClientAdapter respond(Object body, {int statusCode = 200}) {
    final adapter = _RecordingHttpClientAdapter(
      body: jsonEncode(body),
      statusCode: statusCode,
    );
    dioClient.dio.httpClientAdapter = adapter;
    return adapter;
  }

  setUp(() {
    dioClient = DioClient(
      config: AppConfig(
        environment: Environment.production,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
      secureStorage: const _EmptySecureStorageService(),
    );
    repository = NavigationSessionRepositoryImpl(dioClient: dioClient);
  });

  group('NavigationSessionRepositoryImpl requests', () {
    test('start posts with the idempotency key and no body', () async {
      final adapter = respond(navigationSessionJson(), statusCode: 201);

      final session = await repository.start(
        itineraryId: 91,
        idempotencyKey: '6f1c1d36-0a5e-4b64-a3a4-3a2b8a0f39f0',
      );

      expect(adapter.request?.method, 'POST');
      expect(
        adapter.request?.path,
        '/api/v1/itineraries/91/navigation-sessions',
      );
      expect(
        adapter.request?.headers['Idempotency-Key'],
        '6f1c1d36-0a5e-4b64-a3a4-3a2b8a0f39f0',
      );
      expect(adapter.request?.data, isNull);
      expect(session.sessionId, 501);
    });

    test('reach and skip send the device time in UTC', () async {
      final adapter = respond(navigationSessionJson());
      final occurredAt = DateTime.utc(2026, 10, 20, 2, 15);

      await repository.reachItem(
        sessionId: 501,
        itemId: 1002,
        occurredAt: occurredAt,
      );
      expect(adapter.request?.method, 'PUT');
      expect(
        adapter.request?.path,
        '/api/v1/navigation-sessions/501/reached-items/1002',
      );
      expect(adapter.request?.data, {
        'occurredAtUtc': '2026-10-20T02:15:00.000Z',
      });

      await repository.skipItem(
        sessionId: 501,
        itemId: 1002,
        occurredAt: occurredAt,
      );
      expect(
        adapter.request?.path,
        '/api/v1/navigation-sessions/501/skipped-items/1002',
      );
    });

    test('depart sets state Navigating and completion has no body', () async {
      final adapter = respond(navigationSessionJson());

      await repository.depart(
        sessionId: 501,
        occurredAt: DateTime.utc(2026, 10, 20, 3),
      );
      expect(adapter.request?.path, '/api/v1/navigation-sessions/501/state');
      expect(adapter.request?.data, {
        'state': 'Navigating',
        'occurredAtUtc': '2026-10-20T03:00:00.000Z',
      });

      await repository.complete(501);
      expect(adapter.request?.method, 'PUT');
      expect(
        adapter.request?.path,
        '/api/v1/navigation-sessions/501/completion',
      );
      expect(adapter.request?.data, isNull);
    });

    test('getById reads the session', () async {
      final adapter = respond(navigationSessionJson());

      await repository.getById(501);

      expect(adapter.request?.method, 'GET');
      expect(adapter.request?.path, '/api/v1/navigation-sessions/501');
    });
  });

  group('NavigationSessionRepositoryImpl errors', () {
    test('maps active_session_exists with the active session id', () async {
      respond({
        'title': 'An open navigation session already exists.',
        'status': 409,
        'errorCode': 'navigation.active_session_exists',
        'activeSessionId': 77,
        'activeSessionLocation': '/api/v1/navigation-sessions/77',
      }, statusCode: 409);

      await expectLater(
        repository.start(itineraryId: 91, idempotencyKey: 'key'),
        throwsA(
          isA<NavigationFailure>()
              .having(
                (f) => f.reason,
                'reason',
                NavigationFailureReason.activeSessionExists,
              )
              .having((f) => f.activeSessionId, 'activeSessionId', 77),
        ),
      );
    });

    test('maps Backend navigation codes to safe messages', () async {
      for (final (code, status, reason) in [
        (
          'navigation.outside_trip_window',
          409,
          NavigationFailureReason.outsideTripWindow,
        ),
        (
          'navigation.itinerary_not_active',
          409,
          NavigationFailureReason.itineraryNotActive,
        ),
        (
          'navigation.no_navigable_items',
          422,
          NavigationFailureReason.noNavigableItems,
        ),
        (
          'navigation.session_completed',
          409,
          NavigationFailureReason.sessionCompleted,
        ),
        (
          'navigation.item_already_reached',
          409,
          NavigationFailureReason.itemAlreadyReached,
        ),
      ]) {
        respond({
          'title': 'raw backend title',
          'errorCode': code,
        }, statusCode: status);

        await expectLater(
          repository.reachItem(
            sessionId: 1,
            itemId: 2,
            occurredAt: DateTime.utc(2026),
          ),
          throwsA(
            isA<NavigationFailure>()
                .having((f) => f.reason, 'reason', reason)
                .having(
                  (f) => f.message,
                  'message',
                  isNot(contains('raw backend')),
                ),
          ),
          reason: code,
        );
      }
    });

    test('falls back to the shared mapping for other errors', () async {
      respond({'title': 'Server error'}, statusCode: 500);
      await expectLater(repository.getById(1), throwsA(isA<ServerFailure>()));

      respond({'title': 'Forbidden'}, statusCode: 403);
      await expectLater(
        repository.getById(1),
        throwsA(isA<PermissionFailure>()),
      );
    });
  });
}

final class _RecordingHttpClientAdapter implements HttpClientAdapter {
  _RecordingHttpClientAdapter({required this.body, this.statusCode = 200});

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

final class _EmptySecureStorageService implements SecureStorageService {
  const _EmptySecureStorageService();

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}
