import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';

abstract final class ActiveTripDemoFixtures {
  /// DEMO_ONLY: an open Navigating session over five Đà Nẵng stops.
  static NavigationSession createDemoSession({
    int itineraryId = 101,
    int sessionId = 9001,
    TransportMode? transportMode,
  }) {
    final now = DateTime.now().toUtc();
    NavigationSessionItem stop(
      int sequence,
      String name,
      double latitude,
      double longitude,
      int arrivalMinutes,
      int stayMinutes, {
      bool isMandatory = false,
    }) {
      final arrival = now.add(Duration(minutes: arrivalMinutes));
      return NavigationSessionItem(
        itemId: 1000 + sequence,
        sequenceNo: sequence,
        poiId: 10 + sequence,
        poiName: name,
        latitude: latitude,
        longitude: longitude,
        plannedArrival: arrival,
        plannedDeparture: arrival.add(Duration(minutes: stayMinutes)),
        isMandatory: isMandatory,
        status: NavigationItemStatus.pending,
        reachedAt: null,
        skippedAt: null,
      );
    }

    final items = [
      stop(
        1,
        'Marble Mountains (Ngũ Hành Sơn)',
        16.0033,
        108.2635,
        20,
        60,
        isMandatory: true,
      ),
      stop(2, 'Cơm Gà Bà Buội', 16.0350, 108.2250, 100, 45),
      stop(3, 'Bảo tàng Điêu khắc Chăm', 16.0602, 108.2235, 180, 50),
      stop(4, 'Chợ Hàn (Han Market)', 16.0685, 108.2245, 250, 45),
      stop(5, 'Cầu Rồng (Dragon Bridge)', 16.0610, 108.2270, 320, 30),
    ];
    return NavigationSession(
      sessionId: sessionId,
      itineraryId: itineraryId,
      itineraryVersion: 1,
      state: NavigationSessionState.navigating,
      completionReason: null,
      startedAt: now,
      expiresAt: items.last.plannedDeparture.add(const Duration(hours: 6)),
      endedAt: null,
      exploringItemId: null,
      nextItemId: items.first.itemId,
      items: items,
      transportMode: transportMode,
    );
  }

  static OfflineTripPackage createSampleOfflinePackage({
    int itineraryId = 101,
    String title = 'Đà Nẵng City Explorer',
    int version = 1,
    OfflinePackageStatus status = OfflinePackageStatus.notDownloaded,
    double totalSizeMb = 118.5,
    DateTime? lastDownloadedAt,
  }) {
    return OfflineTripPackage(
      itineraryId: itineraryId,
      title: title,
      version: version,
      status: status,
      totalSizeMb: totalSizeMb,
      dateRange: 'Oct 12, 2026',
      stopsCount: 5,
      lastDownloadedAt: lastDownloadedAt,
    );
  }
}
