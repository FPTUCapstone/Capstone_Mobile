import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/network/dio_client.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/offline_trip_remote_data_source.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/mapbox_directions_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';

void main() {
  test('scoped routing requests honor transfer cancellation', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://routing.test.invalid'));
    final adapter = _PendingAdapter();
    dio.httpClientAdapter = adapter;
    final cancellation = CancelToken();
    final routing = MapboxDirectionsRepositoryImpl(
      accessToken: 'pk.test-public',
      dio: dio,
      cancelToken: cancellation,
    );
    final result = routing.getRoute(
      origin: const NavigationCoordinate(latitude: 16, longitude: 108),
      destination: const NavigationCoordinate(
        latitude: 16.01,
        longitude: 108.01,
      ),
    );
    final cancelled = expectLater(result, throwsA(isA<NetworkFailure>()));
    await adapter.started.future;
    cancellation.cancel();
    await cancelled;
    expect(adapter.cancelled, isTrue);
  });
  test(
    'cancel aborts an in-flight itinerary HTTP request before further work',
    () async {
      final client = DioClient(
        config: AppConfig(
          environment: Environment.production,
          apiBaseUrl: Uri.parse('https://api.test.invalid'),
        ),
        secureStorage: _Storage(),
      );
      final adapter = _PendingAdapter();
      client.dio.httpClientAdapter = adapter;
      final source = OfflineTripRemoteDataSource(
        _Itineraries([]),
        _Pois(),
        _Routes(),
        client: client,
      );
      final pending = source.capture(ownerId: 7, itineraryId: 1);
      final cancelled = expectLater(
        pending,
        throwsA(isA<OfflineCaptureCancelled>()),
      );
      await adapter.started.future;
      source.cancel();
      await cancelled;
      expect(adapter.cancelled, isTrue);
    },
  );
  test(
    'pins returned ID; valid coordinate-less rests remain in snapshot',
    () async {
      final itineraries = _Itineraries([_detail(), _detail()]);
      final source = OfflineTripRemoteDataSource(
        itineraries,
        _Pois(),
        _Routes(),
      );
      final snapshot = await source.capture(ownerId: 7, itineraryId: 1);
      expect(snapshot.itinerary.itineraryId, 11);
      expect(snapshot.requestedItineraryId, 1);
      expect(snapshot.itinerary.items.single.itemKind, ItineraryItemKind.rest);
      expect(itineraries.ids, [1, 1]);
    },
  );

  test(
    'detects essential changes even when itinerary version is unchanged',
    () async {
      final source = OfflineTripRemoteDataSource(
        _Itineraries([_detail(), _detail(status: 'Active')]),
        _Pois(),
        _Routes(),
      );
      await expectLater(
        source.capture(ownerId: 7, itineraryId: 1),
        throwsA(isA<ConflictFailure>()),
      );
    },
  );

  test('missing visit coordinate never creates invented geometry', () async {
    final source = OfflineTripRemoteDataSource(
      _Itineraries([_detail(visit: true)]),
      _Pois(),
      _Routes(),
    );
    await expectLater(
      source.capture(ownerId: 7, itineraryId: 1),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('checks cancellation before any remote read', () async {
    final itineraries = _Itineraries([_detail()]);
    final source = OfflineTripRemoteDataSource(itineraries, _Pois(), _Routes());
    await expectLater(
      source.capture(ownerId: 7, itineraryId: 1, isCancelled: () => true),
      throwsA(isA<OfflineCaptureCancelled>()),
    );
    expect(itineraries.ids, isEmpty);
  });

  test('captures referenced POI data once and routes start-to-visit', () async {
    final itineraries = _Itineraries([
      _detail(visit: true, located: true),
      _detail(visit: true, located: true),
    ]);
    final pois = _Pois();
    final directions = _Routes();
    final source = OfflineTripRemoteDataSource(itineraries, pois, directions);
    final snapshot = await source.capture(ownerId: 7, itineraryId: 1);
    expect(snapshot.pois.single.id, 4);
    expect(snapshot.routes.single.geometry.length, 2);
    expect(pois.ids, [4]);
    expect(directions.calls, 1);
  });

  test('propagates access denial without fetching public POIs', () async {
    final source = OfflineTripRemoteDataSource(_Denied(), _Pois(), _Routes());
    await expectLater(
      source.capture(ownerId: 7, itineraryId: 1),
      throwsA(isA<OfflineItineraryAccessDenied>()),
    );
  });

  test('rejects a POI response for a different identifier', () async {
    final source = OfflineTripRemoteDataSource(
      _Itineraries([_detail(visit: true, located: true)]),
      _Pois(wrongId: true),
      _Routes(),
    );
    await expectLater(
      source.capture(ownerId: 7, itineraryId: 1),
      throwsA(isA<ValidationFailure>()),
    );
  });
}

class _Storage implements SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
  @override
  Future<void> deleteAll() async {}
}

class _PendingAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  bool cancelled = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    started.complete();
    await cancelFuture;
    cancelled = true;
    throw DioException(requestOptions: options, type: DioExceptionType.cancel);
  }

  @override
  void close({bool force = false}) {}
}

ItineraryDetail _detail({
  String status = 'Draft',
  bool visit = false,
  bool located = false,
}) => ItineraryDetail(
  itineraryId: 11,
  schedulingRequestId: 2,
  title: 'Saved trip',
  version: 1,
  status: status,
  validFrom: null,
  validTo: null,
  canManage: false,
  totalEstimatedCost: 0,
  totalDurationMinutes: 30,
  startLocation: located
      ? const ItineraryLocation(latitude: 16, longitude: 108)
      : null,
  items: [
    ItineraryDetailItem(
      itemId: 3,
      sequenceNo: 1,
      poiId: visit ? 4 : null,
      poiName: visit ? 'POI' : null,
      category: null,
      itemKind: visit ? ItineraryItemKind.visit : ItineraryItemKind.rest,
      plannedArrival: DateTime.utc(2026, 11, 22, 12),
      plannedDeparture: DateTime.utc(2026, 11, 22, 12, 30),
      travelDurationFromPreviousMinutes: null,
      stayDurationMinutes: 30,
      estimatedCost: null,
      isMandatory: false,
      recommendationReason: null,
      isUnavailable: false,
      latitude: located ? 16.01 : null,
      longitude: located ? 108.01 : null,
    ),
  ],
);

class _Itineraries implements ItineraryRepository {
  _Itineraries(this.responses);
  final List<ItineraryDetail> responses;
  final ids = <int>[];
  @override
  Future<ItineraryDetail> getById(int id) async {
    ids.add(id);
    return responses.removeAt(0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pois implements PoiRepository {
  _Pois({this.wrongId = false});
  final bool wrongId;
  final ids = <int>[];
  @override
  Future<PoiDetail> getPoiDetail(int id) async {
    ids.add(id);
    return PoiDetail(
      id: wrongId ? id + 1 : id,
      name: 'POI',
      description: 'Saved text',
      status: 'Active',
      categoryId: 1,
      categoryName: 'Visit',
      latitude: 16.01,
      longitude: 108.01,
      indoorOutdoor: 'Outdoor',
      averageVisitDurationMinutes: 30,
      hasShelter: false,
      reviewCount: 0,
      isOpenNow: true,
      openingHours: const [],
      photos: const [],
      tags: const [],
      createdAtUtc: DateTime.utc(2026),
      updatedAtUtc: DateTime.utc(2026),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Routes implements RouteDirectionsRepository {
  int calls = 0;
  @override
  bool get isAvailable => true;
  @override
  Future<NavigationRoute> getRoute({
    required NavigationCoordinate origin,
    required NavigationCoordinate destination,
    TransportMode? transportMode,
  }) async {
    calls++;
    return NavigationRoute(
      geometry: [origin, destination],
      distanceMeters: 100,
      durationSeconds: 20,
      steps: const [],
    );
  }
}

class _Denied implements ItineraryRepository {
  @override
  Future<ItineraryDetail> getById(int id) async =>
      throw const PermissionFailure();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
