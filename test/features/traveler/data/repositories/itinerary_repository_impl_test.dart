import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/itinerary_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_stop.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';

void main() {
  late DioClient dioClient;
  late ItineraryRepositoryImpl repository;

  _RecordingAdapter respond(Object body, {int statusCode = 200}) {
    final adapter = _RecordingAdapter(
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
    repository = ItineraryRepositoryImpl(dioClient: dioClient);
  });

  test('updateStops sends the stops with their leg transport', () async {
    final adapter = respond(_detailJson(itineraryId: 11, version: 2));

    final detail = await repository.updateStops(
      itineraryId: 10,
      stops: const [
        ItineraryStop(poiId: 12, transportModeToNext: TransportMode.motorbike),
        ItineraryStop(poiId: 88, transportModeToNext: TransportMode.walking),
        ItineraryStop(poiId: 35),
      ],
      idempotencyKey: 'key-1',
    );

    expect(adapter.request?.method, 'PUT');
    expect(adapter.request?.path, '/api/v1/itineraries/10/items');
    expect(adapter.request?.headers['Idempotency-Key'], 'key-1');
    expect(adapter.request?.data, {
      'stops': [
        {'poiId': 12, 'transportModeToNext': 'Motorbike'},
        {'poiId': 88, 'transportModeToNext': 'Walking'},
        {'poiId': 35},
      ],
    });
    expect(detail.itineraryId, 11);
    expect(detail.version, 2);
  });

  test('food suggestions are asked for after a stop', () async {
    final adapter = respond({
      'itineraryId': 10,
      'kind': 'Food',
      'searchRadiusKm': 15,
      'items': <Object>[],
    });

    final result = await repository.getSuggestions(
      itineraryId: 10,
      kind: SuggestionKind.food,
      itemId: 77,
    );

    expect(adapter.request?.method, 'GET');
    expect(adapter.request?.path, '/api/v1/itineraries/10/suggestions');
    expect(adapter.request?.queryParameters, {
      'kind': 'Food',
      'afterItemId': 77,
    });
    expect(result.items, isEmpty);
    expect(result.searchRadiusKm, 15);
  });

  test('replacement suggestions name the stop to replace', () async {
    final adapter = respond({
      'itineraryId': 10,
      'kind': 'Replace',
      'searchRadiusKm': 15,
      'items': <Object>[],
    });

    await repository.getSuggestions(
      itineraryId: 10,
      kind: SuggestionKind.replace,
      itemId: 78,
    );

    expect(adapter.request?.queryParameters, {
      'kind': 'Replace',
      'replaceItemId': 78,
    });
  });

  test('updateStops reports the stop that does not fit', () async {
    respond({
      'title': 'A selected location does not fit the itinerary.',
      'errorCode': 'itinerary.stop_infeasible',
      'poiId': 88,
      'reason': 'ExceedsEndTime',
      'overflowMinutes': 80,
    }, statusCode: 422);

    await expectLater(
      repository.updateStops(
        itineraryId: 10,
        stops: const [ItineraryStop(poiId: 88)],
        idempotencyKey: 'key-2',
      ),
      throwsA(
        isA<StopInfeasibleFailure>()
            .having((failure) => failure.poiId, 'poiId', 88)
            .having((failure) => failure.overflowMinutes, 'overflow', 80),
      ),
    );
  });
}

Map<String, Object?> _detailJson({int itineraryId = 10, int version = 1}) => {
  'itineraryId': itineraryId,
  'schedulingRequestId': 20,
  'title': 'Day plan',
  'version': version,
  'status': 'Draft',
  'validFrom': '2026-10-18T01:00:00Z',
  'validTo': '2026-10-18T10:00:00Z',
  'canManage': true,
  'totalEstimatedCost': 0,
  'totalDurationMinutes': 540,
  'items': <Object>[],
};

final class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.body, this.statusCode = 200});

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
