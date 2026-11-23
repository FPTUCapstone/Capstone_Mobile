import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/poi/domain/entities/poi_detail.dart';
import 'package:trip_mate_mobile/features/traveler/data/datasources/offline_trip_local_data_source.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/offline_trip_manifest_model.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/active_trip_maneuver.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_route.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';

void main() {
  late Directory root;
  late OfflineTripLocalDataSource source;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('uc16-local-');
    source = OfflineTripLocalDataSource(root);
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'publication order wins over a backwards clock even for the same version',
    () async {
      final base = package();
      OfflineTripManifest generation(String id, DateTime time) =>
          OfflineTripManifest(
            snapshot: base.snapshot,
            generation: id,
            regionId: 'region-$id',
            styleUri: base.styleUri,
            styleBytes: base.styleBytes,
            tileBytes: base.tileBytes,
            downloadedAtUtc: time,
          );
      await source.commit(generation('old', DateTime.utc(2026, 11, 23)));
      await source.commit(generation('new', DateTime.utc(2026, 11, 22)));
      expect((await source.list(7)).single.generation, 'new');
      expect((await source.read(7, 10))?.generation, 'new');
      expect((await source.removeObsolete(7, 10)).single.generation, 'old');
      expect((await source.read(7, 10))?.generation, 'new');
    },
  );

  test('saved coverage is versioned and unsupported coverage is rejected', () {
    final data =
        jsonDecode(utf8.decode(OfflineTripManifestModel.encode(package())))
            as Map<String, dynamic>;
    expect(data['coverage'], {
      'minimumZoom': 10,
      'maximumZoom': 16,
      'bufferMeters': 1000,
    });
    (data['coverage'] as Map<String, dynamic>)['maximumZoom'] = 17;
    expect(
      () => OfflineTripManifestModel.decode(utf8.encode(jsonEncode(data))),
      throwsFormatException,
    );
  });

  test(
    'persists a verified generation across restart and isolates accounts',
    () async {
      final saved = await source.commit(package());
      expect(saved.dataBytes, greaterThan(0));
      final reopened = OfflineTripLocalDataSource(root);
      expect((await reopened.read(7, 10))?.snapshot.itinerary.title, 'My trip');
      expect((await reopened.read(7, 11))?.snapshot.itinerary.version, 1);
      expect(await reopened.list(8), isEmpty);
      expect(await reopened.read(8, 10), isNull);
    },
  );

  test(
    'rejects over budget replacement and retains old committed data',
    () async {
      await source.commit(package());
      await expectLater(
        source.commit(
          package(generation: 'next', version: 2, tileBytes: 150000000),
        ),
        throwsA(isA<OfflineStorageLimitException>()),
      );
      expect((await source.read(7, 10))?.snapshot.itinerary.version, 1);
    },
  );

  test(
    'never exposes staging data and recovery removes abandoned staging',
    () async {
      await source.commit(package());
      final partial = Directory('${root.path}/7/staging-abandoned');
      await partial.create();
      await File('${partial.path}/payload.json').writeAsString('{}');
      expect((await source.list(7)).length, 1);
      await source.recover(7);
      expect(await partial.exists(), isFalse);
      expect((await source.list(7)).length, 1);
    },
  );

  test(
    'integrity verification rejects even same-length content corruption',
    () async {
      await source.commit(package());
      final file = File('${root.path}/7/first/payload.json');
      final text = await file.readAsString();
      await file.writeAsString(text.replaceFirst('My trip', 'Badtrip'));
      await expectLater(
        source.read(7, 10),
        throwsA(isA<OfflineDataCorruptException>()),
      );
      expect(await source.list(7), isEmpty);
      expect(await source.unreadableGenerations(7), ['first']);
      await source.removeUnreadable(7, 'first');
      expect(await source.unreadableGenerations(7), isEmpty);
    },
  );

  test(
    'refresh publishes latest completely and removal returns resource refs',
    () async {
      await source.commit(package());
      await source.commit(package(generation: 'second', version: 2));
      expect((await source.list(7)).length, 1);
      expect((await source.read(7, 10))?.snapshot.itinerary.version, 2);
      final removed = await source.remove(7, 10);
      expect(
        removed.map((item) => item.regionId),
        containsAll(['region-first', 'region-second']),
      );
      expect(await source.list(7), isEmpty);
    },
  );

  test(
    'lock and superseded flags persist without corrupting package',
    () async {
      await source.commit(package());
      await source.setLocked(7, 10, true);
      expect((await source.read(7, 10))?.locked, isTrue);
      await source.setSuperseded(7, 10, true);
      final reopened = await OfflineTripLocalDataSource(root).read(7, 10);
      expect(reopened?.superseded, isTrue);
      expect(reopened?.locked, isTrue);
    },
  );

  test(
    'rejects traversal generation and invalid account identifiers',
    () async {
      await expectLater(
        source.commit(package(generation: '../escape')),
        throwsArgumentError,
      );
      await expectLater(source.list(0), throwsArgumentError);
      expect(await Directory('${root.parent.path}/escape').exists(), isFalse);
    },
  );

  test('duplicate generation cannot overwrite an installed package', () async {
    await source.commit(package());
    await expectLater(source.commit(package(version: 2)), throwsStateError);
    expect((await source.read(7, 10))?.snapshot.itinerary.version, 1);
  });

  test(
    'manual itineraries with scheduling request zero remain separate',
    () async {
      await source.commit(package(schedulingRequestId: 0));
      await source.commit(
        package(
          generation: 'other',
          schedulingRequestId: 0,
          itineraryId: 12,
          requestedId: 20,
        ),
      );
      expect((await source.list(7)).length, 2);
      await source.remove(7, 10);
      expect((await source.read(7, 20))?.itineraryId, 12);
      expect((await source.list(7)).length, 1);
    },
  );

  test(
    'corrupt old generation does not block healthy current or other package',
    () async {
      await source.commit(package());
      await source.commit(package(generation: 'second', version: 2));
      await source.commit(
        package(
          generation: 'third',
          schedulingRequestId: 8,
          itineraryId: 20,
          requestedId: 19,
        ),
      );
      await File('${root.path}/7/first/payload.json').writeAsString('broken');
      expect((await source.read(7, 10))?.version, 2);
      expect((await source.list(7)).length, 2);
      expect(await source.unreadableGenerations(7), ['first']);
      await source.remove(7, 10);
      expect((await source.read(7, 19))?.itineraryId, 20);
      await source.removeUnreadable(7, 'first');
      expect(await source.unreadableGenerations(7), isEmpty);
      await expectLater(
        source.removeUnreadable(7, '../escape'),
        throwsArgumentError,
      );
    },
  );

  test(
    'obsolete cleanup preserves newest locked package and other families',
    () async {
      await source.commit(package());
      await source.commit(package(generation: 'second', version: 2));
      await source.commit(
        package(
          generation: 'third',
          schedulingRequestId: 8,
          itineraryId: 20,
          requestedId: 19,
        ),
      );
      await source.setLocked(7, 10, true);
      final removed = await source.removeObsolete(7, 10);
      expect(removed.map((item) => item.regionId), ['region-first']);
      expect((await source.read(7, 10))?.version, 2);
      expect((await source.read(7, 10))?.locked, isTrue);
      expect((await source.read(7, 19))?.itineraryId, 20);
      expect((await source.list(7)).length, 2);
    },
  );

  test(
    'accepts exactly 150 MB but rejects one byte above measured package',
    () async {
      var tiles = OfflineTripManifest.maxBytes - 20;
      for (var i = 0; i < 3; i++) {
        tiles =
            OfflineTripManifest.maxBytes -
            20 -
            OfflineTripManifestModel.encodedSize(package(tileBytes: tiles));
      }
      final saved = await source.commit(package(tileBytes: tiles));
      expect(saved.totalBytes, OfflineTripManifest.maxBytes);
      await expectLater(
        source.commit(package(generation: 'other', tileBytes: tiles + 1)),
        throwsA(isA<OfflineStorageLimitException>()),
      );
    },
  );

  test(
    'round trips POI opening hours and route geometry/steps without photos',
    () async {
      final base = package();
      final point = NavigationCoordinate(latitude: 16.1, longitude: 108.2);
      final snapshot = OfflineTripSnapshot(
        ownerId: 7,
        requestedItineraryId: 10,
        itinerary: base.snapshot.itinerary,
        capturedAtUtc: base.snapshot.capturedAtUtc,
        pois: [
          PoiDetail(
            id: 3,
            name: 'Museum',
            description: 'Essential information',
            status: 'Active',
            categoryId: 1,
            categoryName: 'Museum',
            latitude: 16.1,
            longitude: 108.2,
            indoorOutdoor: 'Indoor',
            averageVisitDurationMinutes: 30,
            hasShelter: true,
            reviewCount: 99,
            isOpenNow: true,
            openingHours: const [
              PoiOpeningHour(
                dayOfWeek: 1,
                openTime: '08:00',
                closeTime: '18:00',
                isClosed: false,
              ),
            ],
            photos: const [
              PoiPhoto(
                id: 1,
                url: 'https://example.test/image.jpg',
                sortOrder: 1,
              ),
            ],
            tags: const [],
            createdAtUtc: DateTime.utc(2026),
            updatedAtUtc: DateTime.utc(2026, 11),
          ),
        ],
        routes: [
          NavigationRoute(
            geometry: [
              point,
              const NavigationCoordinate(latitude: 16.2, longitude: 108.3),
            ],
            distanceMeters: 100,
            durationSeconds: 30,
            steps: [
              NavigationStep(
                instruction: 'Continue',
                direction: ManeuverDirection.straight,
                location: point,
                distanceMeters: 100,
              ),
            ],
          ),
        ],
      );
      await source.commit(
        OfflineTripManifest(
          snapshot: snapshot,
          generation: base.generation,
          regionId: base.regionId,
          styleUri: base.styleUri,
          styleBytes: base.styleBytes,
          tileBytes: base.tileBytes,
          downloadedAtUtc: base.downloadedAtUtc,
        ),
      );
      final loaded = (await source.read(7, 10))!.snapshot;
      expect(loaded.pois.single.openingHours.single.openTime, '08:00');
      expect(loaded.pois.single.updatedAtUtc, DateTime.utc(2026, 11));
      expect(loaded.pois.single.photos, isEmpty);
      expect(loaded.routes.single.geometry.last.longitude, 108.3);
      expect(loaded.routes.single.steps.single.instruction, 'Continue');
      expect(loaded.itinerary.canManage, isFalse);
    },
  );
}

OfflineTripManifest package({
  String generation = 'first',
  int version = 1,
  int tileBytes = 100,
  int schedulingRequestId = 4,
  int itineraryId = 11,
  int requestedId = 10,
}) => OfflineTripManifest(
  snapshot: OfflineTripSnapshot(
    ownerId: 7,
    requestedItineraryId: requestedId,
    itinerary: ItineraryDetail(
      itineraryId: itineraryId,
      schedulingRequestId: schedulingRequestId,
      title: 'My trip',
      version: version,
      status: 'Active',
      validFrom: DateTime.utc(2026, 11, 22),
      validTo: DateTime.utc(2026, 11, 23),
      canManage: true,
      totalEstimatedCost: 0,
      totalDurationMinutes: 60,
      items: const [],
    ),
    pois: const [],
    routes: const [],
    capturedAtUtc: DateTime.utc(2026, 11, 22),
  ),
  generation: generation,
  regionId: 'region-$generation',
  styleUri: 'mapbox://styles/mapbox/streets-v12',
  styleBytes: 20,
  tileBytes: tileBytes,
  downloadedAtUtc: DateTime.utc(2026, 11, 22, version),
);
