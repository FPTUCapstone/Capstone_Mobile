import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_manifest.dart';

enum OfflineTransferPhase { preparing, itinerary, maps, verifying, publishing }

final class OfflineOperationCancelled implements Exception {
  const OfflineOperationCancelled();
}

final class OfflineDownloadProgress {
  const OfflineDownloadProgress({
    required this.phase,
    required this.fraction,
    this.completedBytes = 0,
    this.estimatedBytes,
  });
  final OfflineTransferPhase phase;
  final double fraction;
  final int completedBytes;
  final int? estimatedBytes;
}

/// Scoped to the securely retained current account by its implementation.
abstract interface class OfflineTripRepository {
  Future<List<OfflineTripManifest>> list();
  Future<OfflineTripManifest?> read(int itineraryId);
  Future<OfflineTripManifest> download(
    int itineraryId, {
    void Function(OfflineDownloadProgress)? onProgress,
  });
  Future<void> cancel();
  Future<void> remove(int itineraryId);
  Future<OfflineTripManifest?> checkForUpdate(int itineraryId);
  Future<List<String>> unreadableGenerations();
  Future<void> removeUnreadable(String generation);
}
