import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_detail.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/offline_trip_repository.dart';

OfflineTripManifest offlineFixture({
  bool locked = false,
  bool superseded = false,
  ItineraryLocation? startLocation,
}) => OfflineTripManifest(
  snapshot: OfflineTripSnapshot(
    ownerId: 7,
    requestedItineraryId: 10,
    itinerary: ItineraryDetail(
      itineraryId: 11,
      schedulingRequestId: 2,
      title: 'Local trip',
      version: 1,
      status: 'Active',
      validFrom: DateTime.utc(2026, 11, 22),
      validTo: DateTime.utc(2026, 11, 23),
      canManage: false,
      totalEstimatedCost: 0,
      totalDurationMinutes: 60,
      items: const [],
      startLocation: startLocation,
    ),
    pois: const [],
    routes: const [],
    capturedAtUtc: DateTime.utc(2026, 11, 22),
  ),
  generation: 'fixture-1',
  regionId: 'region-1',
  styleUri: 'mapbox://styles/mapbox/standard',
  styleBytes: 10,
  tileBytes: 20,
  downloadedAtUtc: DateTime.utc(2026, 11, 22),
  locked: locked,
  superseded: superseded,
  mapResourcesAvailable: true,
);

class FakeOfflineRepository implements OfflineTripRepository {
  OfflineTripManifest? manifest = offlineFixture();
  List<String> unreadable = [];
  Object? failure;
  final calls = <String>[];
  Future<OfflineTripManifest> Function()? transfer;
  Future<void> Function()? cancellation;
  Object? updateFailure;
  void Function(OfflineDownloadProgress)? progressCallback;
  @override
  Future<List<OfflineTripManifest>> list() async {
    calls.add('list');
    if (failure != null) throw failure!;
    return [?manifest];
  }

  @override
  Future<OfflineTripManifest?> read(int itineraryId) async {
    calls.add('read');
    if (failure != null) throw failure!;
    return manifest;
  }

  @override
  Future<OfflineTripManifest> download(
    int itineraryId, {
    void Function(OfflineDownloadProgress)? onProgress,
  }) async {
    calls.add('download');
    progressCallback = onProgress;
    if (transfer != null) return transfer!();
    if (failure != null) throw failure!;
    return manifest ?? offlineFixture();
  }

  @override
  Future<void> cancel() async {
    calls.add('cancel');
    await cancellation?.call();
  }

  @override
  Future<void> remove(int itineraryId) async {
    calls.add('remove');
    manifest = null;
  }

  @override
  Future<OfflineTripManifest?> checkForUpdate(int itineraryId) async {
    calls.add('check');
    if (updateFailure != null) throw updateFailure!;
    return manifest;
  }

  @override
  Future<List<String>> unreadableGenerations() async => unreadable;
  @override
  Future<void> removeUnreadable(String generation) async {
    unreadable.remove(generation);
  }
}
