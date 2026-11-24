import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/poi/domain/repositories/poi_repository.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/offline_map_data_source.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/offline_trip_local_data_source.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/offline_trip_remote_data_source.dart';
import 'package:trip_mate_mobile/features/traveler/data/repositories/offline_trip_repository_impl.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/itinerary_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/route_directions_repository.dart';

void main() {
  late Directory root;
  late OfflineTripLocalDataSource local;
  late _Maps maps;
  late _Remote remote;
  late OfflineTripRepositoryImpl repository;
  var owner = 7;
  var key = 'session-7';
  setUp(() async {
    root = await Directory.systemTemp.createTemp('uc16-repository-');
    local = OfflineTripLocalDataSource(root);
    maps = _Maps();
    remote = _Remote();
    owner = 7;
    key = 'session-7';
    repository = OfflineTripRepositoryImpl(
      local: () async => local,
      maps: maps,
      remote: remote,
      ownerId: () async => owner,
      onlineOwnerId: () async => owner,
      sessionKey: () async => key,
      isMapConfigured: () => true,
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test(
    'stale validation denial cannot lock a previous account package',
    () async {
      await repository.download(1);
      remote.version = 2;
      remote.validationPending = Completer<void>();
      remote.validationEntered = Completer<void>();
      final result = repository.download(1);
      final failed = expectLater(result, throwsA(isA<AuthenticationFailure>()));
      await remote.validationEntered!.future;
      owner = 8;
      key = 'session-8';
      remote.validationPending!.completeError(const PermissionFailure());
      await failed;
      expect((await local.read(7, 1))?.locked, isFalse);
    },
  );

  test(
    'denial of itinerary access during preparation locks the retained package',
    () async {
      await repository.download(1);
      remote.captureFailure = const OfflineItineraryAccessDenied();
      await expectLater(
        repository.download(1),
        throwsA(isA<PermissionFailure>()),
      );
      expect((await repository.read(1))?.locked, isTrue);
    },
  );

  test(
    'publishes only verified data and opens persisted package without HTTP',
    () async {
      final saved = await repository.download(1);
      expect(saved.totalBytes, greaterThan(200));
      expect(remote.validations, 1);
      remote.denyReads = true;
      expect((await repository.read(1))?.version, 1);
      expect((await repository.read(1))?.mapResourcesAvailable, isTrue);
      expect((await repository.list()).single.itineraryId, 11);
    },
  );
  test('insufficient device space rejects before transfer', () async {
    maps.free = 149999999;
    await expectLater(
      repository.download(1),
      throwsA(isA<ValidationFailure>()),
    );
    expect(maps.downloads, 0);
    expect(await local.list(7), isEmpty);
  });
  test(
    'actual oversized resources are discarded and never committed',
    () async {
      maps.tileBytes = 150000000;
      await expectLater(
        repository.download(1),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await local.list(7), isEmpty);
      expect(maps.removed, isNotEmpty);
    },
  );
  test(
    'cancelled in-flight native transfer cannot publish a late success',
    () async {
      maps.pending = Completer<OfflineMapDownload>();
      final result = repository.download(1);
      final failed = expectLater(
        result,
        throwsA(isA<OfflineOperationCancelled>()),
      );
      await maps.entered.future;
      await repository.cancel();
      maps.pending!.complete(maps.result());
      await failed;
      expect(await local.list(7), isEmpty);
    },
  );
  test(
    'account switch prevents old operation from committing for either account',
    () async {
      maps.pending = Completer<OfflineMapDownload>();
      final result = repository.download(1);
      final failed = expectLater(result, throwsA(isA<AuthenticationFailure>()));
      await maps.entered.future;
      owner = 8;
      key = 'session-8';
      maps.pending!.complete(maps.result());
      await failed;
      expect(await local.list(7), isEmpty);
      expect(await local.list(8), isEmpty);
    },
  );
  test('failed replacement retains old complete data', () async {
    await repository.download(1);
    remote.version = 2;
    remote.failValidation = true;
    await expectLater(repository.download(1), throwsA(isA<ConflictFailure>()));
    expect((await repository.read(1))?.version, 1);
  });

  test(
    'network interruption reports discarded transfer and retains installed copy',
    () async {
      await repository.download(1);
      remote.captureFailure = const NetworkFailure();
      await expectLater(
        repository.download(1),
        throwsA(
          isA<NetworkFailure>().having(
            (error) => error.message,
            'message',
            contains('nothing partial was kept'),
          ),
        ),
      );
      expect((await local.read(7, 1))?.version, 1);
      expect(maps.downloads, 1);
    },
  );
  test(
    'authoritative itinerary denial locks retained data; transient failure does not',
    () async {
      await repository.download(1);
      remote.denial = const ServerFailure();
      await expectLater(
        repository.checkForUpdate(1),
        throwsA(isA<ServerFailure>()),
      );
      expect((await repository.read(1))?.locked, isFalse);
      remote.denial = const PermissionFailure();
      await expectLater(
        repository.checkForUpdate(1),
        throwsA(isA<PermissionFailure>()),
      );
      expect((await repository.read(1))?.locked, isTrue);
    },
  );
  test('missing native resources never appear openable', () async {
    await repository.download(1);
    maps.missing = true;
    await expectLater(repository.read(1), throwsA(isA<ServerFailure>()));
    expect((await repository.list()).single.mapResourcesAvailable, isFalse);
  });
  test(
    'wrapped longitude coverage is split rather than downloading the world',
    () {
      final geometry = offlineCoverageGeometry([
        const NavigationCoordinate(latitude: 16, longitude: 179.99),
        const NavigationCoordinate(latitude: 16, longitude: -179.99),
      ]);
      expect(geometry['type'], 'MultiPolygon');
    },
  );

  test('publication is an explicit non-cancellable atomic boundary', () async {
    final slow = _DelayedLocal(root);
    local = slow;
    final downloading = repository.download(1);
    final completesSave = expectLater(downloading, completes);
    await slow.entered.future;
    Object? cancelError;
    try {
      await repository.cancel();
    } catch (error) {
      cancelError = error;
    }
    slow.release.complete();
    await completesSave;
    expect(cancelError, isA<ConflictFailure>());
    expect((await local.read(7, 1))?.version, 1);
  });

  test('version checks serialize with replacement publication', () async {
    await repository.download(1);
    remote.currentPending = Completer<ItineraryDetail>();
    final checking = repository.checkForUpdate(1);
    await remote.currentEntered.future;
    final blocked = expectLater(
      repository.download(1),
      throwsA(isA<ConflictFailure>()),
    );
    remote.currentPending!.complete(remote.detail());
    await checking;
    await blocked;
  });

  test('startup keeps every retained committed generation reference', () async {
    OfflineTripManifest stored(int version) {
      remote.version = version;
      return OfflineTripManifest(
        snapshot: OfflineTripSnapshot(
          ownerId: 7,
          requestedItineraryId: 1,
          itinerary: remote.detail(),
          pois: const [],
          routes: const [],
          capturedAtUtc: DateTime.utc(2026),
        ),
        generation: 'gen-$version',
        regionId: 'tripmate-offline-retained-$version',
        styleUri: 'mapbox://styles/mapbox/standard',
        styleBytes: 100,
        tileBytes: 100,
        downloadedAtUtc: DateTime.utc(2026, 1, version),
      );
    }

    await local.commit(stored(1));
    await local.commit(stored(2));
    maps.knownRegions = [
      'tripmate-offline-retained-1',
      'tripmate-offline-retained-2',
      'tripmate-offline-orphan',
    ];
    await repository.list();
    expect(maps.removed, ['tripmate-offline-orphan']);
  });

  test('failed native cleanup is retried on the next open', () async {
    maps.downloadFailure = PlatformException(code: 'cleanup_failed');
    await expectLater(repository.download(1), throwsA(isA<ServerFailure>()));
    maps.downloadFailure = null;
    maps.knownRegions = ['tripmate-offline-orphan'];
    await repository.list();
    expect(maps.removed, ['tripmate-offline-orphan']);
  });
}

class _DelayedLocal extends OfflineTripLocalDataSource {
  _DelayedLocal(super.root);
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<OfflineTripManifest> commit(OfflineTripManifest manifest) async {
    entered.complete();
    await release.future;
    return super.commit(manifest);
  }
}

class _Maps extends OfflineMapDataSource {
  int free = 300000000, tileBytes = 100, downloads = 0;
  bool missing = false;
  List<String> knownRegions = [];
  PlatformException? downloadFailure;
  String currentRegion = '';
  final removed = <String>[];
  final entered = Completer<void>();
  Completer<OfflineMapDownload>? pending;
  OfflineMapDownload result() => OfflineMapDownload(
    regionId: currentRegion,
    styleUri: 'mapbox://styles/mapbox/standard',
    styleBytes: 100,
    tileBytes: tileBytes,
  );
  @override
  Future<void> initialize() async {}
  @override
  Future<List<String>> regions() async => knownRegions;
  @override
  Future<Map<String, Object?>> storage() async => {'freeBytes': free};
  @override
  Future<int?> estimate({
    required String regionId,
    required Map<String, Object?> geometry,
  }) async => null;
  @override
  Future<OfflineMapDownload> download({
    required String regionId,
    required Map<String, Object?> geometry,
    required int maxBytes,
    void Function(int, int, int)? onProgress,
  }) async {
    currentRegion = regionId;
    downloads++;
    if (!entered.isCompleted) entered.complete();
    if (downloadFailure != null) throw downloadFailure!;
    return pending == null ? result() : await pending!.future;
  }

  @override
  Future<OfflineMapDownload> verify(String regionId) async {
    if (missing) throw StateError('Missing resources');
    return OfflineMapDownload(
      regionId: regionId,
      styleUri: 'mapbox://styles/mapbox/standard',
      styleBytes: 100,
      tileBytes: 100,
    );
  }

  @override
  Future<void> cancel() async {}
  @override
  Future<void> remove(String regionId) async {
    removed.add(regionId);
  }
}

class _Remote extends OfflineTripRemoteDataSource {
  _Remote() : super(_Itineraries(), _Pois(), _Directions());
  int version = 1, validations = 0;
  bool denyReads = false, failValidation = false;
  Failure? denial;
  Object? captureFailure;
  Completer<void>? validationPending, validationEntered;
  Completer<ItineraryDetail>? currentPending;
  final currentEntered = Completer<void>();
  ItineraryDetail detail() => ItineraryDetail(
    itineraryId: version == 1 ? 11 : 12,
    schedulingRequestId: 2,
    title: 'Trip',
    version: version,
    status: 'Active',
    validFrom: null,
    validTo: null,
    canManage: false,
    totalEstimatedCost: 0,
    totalDurationMinutes: 60,
    items: const [],
    startLocation: const ItineraryLocation(latitude: 16, longitude: 108),
  );
  @override
  Future<OfflineTripSnapshot> capture({
    required int ownerId,
    required int itineraryId,
    bool Function()? isCancelled,
  }) async {
    if (captureFailure != null) throw captureFailure!;
    if (denyReads) throw StateError('Offline reads must not call HTTP');
    return OfflineTripSnapshot(
      ownerId: ownerId,
      requestedItineraryId: itineraryId,
      itinerary: detail(),
      pois: const [],
      routes: const [],
      capturedAtUtc: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> validate(OfflineTripSnapshot snapshot) async {
    validations++;
    if (validationPending != null) {
      if (!(validationEntered?.isCompleted ?? true)) {
        validationEntered!.complete();
      }
      await validationPending!.future;
    }
    if (failValidation) throw const ConflictFailure();
  }

  @override
  Future<ItineraryDetail> current(int id) async {
    if (!currentEntered.isCompleted) currentEntered.complete();
    if (denial != null) throw denial!;
    if (currentPending != null) return await currentPending!.future;
    return detail();
  }
}

class _Itineraries implements ItineraryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pois implements PoiRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Directions implements RouteDirectionsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
