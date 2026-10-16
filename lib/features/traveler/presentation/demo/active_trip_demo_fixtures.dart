import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/offline_trip_package.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';

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

  static List<TripAlert> createSampleAlerts() {
    final now = DateTime.now();
    return [
      TripAlert(
        id: 'alert-weather-1',
        title: 'Severe weather warning',
        description:
            'Heavy rain (42 mm/h) forecast near Han Market between 14:00 and 16:00. Stop 4 is affected.',
        severity: AlertSeverity.critical,
        type: TripAlertType.weather,
        affectedStopName: 'Chợ Hàn (Han Market)',
        timestamp: now.subtract(const Duration(minutes: 2)),
        rerouteProposalAvailable: true,
      ),
      TripAlert(
        id: 'alert-delay-2',
        title: 'Schedule delay detected',
        description:
            'Stop 2 (Cơm Gà Bà Buội) is running 25 minutes behind planned timeline.',
        severity: AlertSeverity.warning,
        type: TripAlertType.delay,
        affectedStopName: 'Cơm Gà Bà Buội',
        timestamp: now.subtract(const Duration(minutes: 45)),
        rerouteProposalAvailable: false,
      ),
      TripAlert(
        id: 'alert-closure-3',
        title: 'POI closed for maintenance',
        description:
            'Bảo tàng Điêu khắc Chăm is closed today for unscheduled electrical maintenance.',
        severity: AlertSeverity.info,
        type: TripAlertType.closure,
        affectedStopName: 'Bảo tàng Điêu khắc Chăm',
        timestamp: now.subtract(const Duration(hours: 2)),
        rerouteProposalAvailable: true,
      ),
      TripAlert(
        id: 'alert-deviation-4',
        title: 'Route deviation detected',
        description:
            'You left the planned route by more than 500 m near Võ Nguyên Giáp.',
        severity: AlertSeverity.critical,
        type: TripAlertType.deviation,
        affectedStopName: 'Võ Nguyên Giáp segment',
        timestamp: now.subtract(const Duration(hours: 3)),
        rerouteProposalAvailable: true,
      ),
    ];
  }

  static RerouteProposal createSampleRerouteProposal() {
    return RerouteProposal(
      proposalId: 'reroute-weather-safe-1',
      reason:
          'Heavy rainfall along active itinerary. Indoor shelter alternatives available.',
      currentStops: const [
        '1. Marble Mountains',
        '2. Cơm Gà Bà Buội (11:40)',
        '3. Bảo tàng Điêu khắc Chăm (13:20)',
        '4. Chợ Hàn [Outdoor Area - Heavy Rain] (14:45)',
        '5. Cầu Rồng (16:30)',
      ],
      proposedStops: const [
        '1. Marble Mountains',
        '2. Cơm Gà Bà Buội (11:40)',
        '3. Bảo tàng Điêu khắc Chăm (13:20)',
        '4. Helio Center [Indoor Complex] (14:15)',
        '5. Cầu Rồng (16:00)',
      ],
      travelTimeDiffMinutes: -15,
      arrivalTimeDiffMinutes: -30,
      affectedStops: const ['Stop 4 replaced: Chợ Hàn ➔ Helio Center (Indoor)'],
      status: RerouteStatus.pending,
      raisedAt: DateTime.now(),
      costDiffVnd: -50000,
      distanceDiffKm: 1.8,
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
