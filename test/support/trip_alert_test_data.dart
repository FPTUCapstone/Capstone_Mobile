import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';

/// Test-only data for the UC-14 alert and UC-15 reroute UI. Production code
/// has no sample alerts or proposals: alerts come from the Backend.
abstract final class TripAlertTestData {
  static List<TripAlert> sampleAlerts() {
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

  static RerouteProposal sampleRerouteProposal() {
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
}
