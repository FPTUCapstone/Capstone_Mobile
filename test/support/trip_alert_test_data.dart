import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/trip_alert.dart';

/// Test-only data for the UC-14 alert and UC-15 reroute UI. Production code
/// has no sample alerts or proposals: alerts and proposals come from the
/// Backend.
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
        reroutingProposalId: 77,
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
        reroutingProposalId: 78,
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
        reroutingProposalId: 79,
      ),
    ];
  }

  static RerouteProposal sampleRerouteProposal({
    RerouteStatus status = RerouteStatus.pending,
    DateTime? expiresAt,
    int arrivalTimeDiffMinutes = -30,
    int travelTimeDiffMinutes = -15,
  }) {
    final proposedAt = DateTime.utc(2026, 11, 25, 3);
    RerouteStop stop(
      String name,
      int hour, {
      RerouteStopChange? change,
      bool isMandatory = false,
    }) => RerouteStop(
      name: name,
      plannedArrival: DateTime.utc(2026, 11, 25, hour),
      plannedDeparture: DateTime.utc(2026, 11, 25, hour, 45),
      isMandatory: isMandatory,
      change: change,
    );
    return RerouteProposal(
      proposalId: 77,
      incidentId: 42,
      status: status,
      reason: const RerouteReason(
        code: 'trip_alert.severe_weather',
        strategy: 'ReplaceWithIndoor',
        affectedPoiName: 'Chợ Hàn',
      ),
      currentStops: [stop('Chợ Hàn', 7), stop('Cầu Rồng', 9)],
      proposedStops: [
        stop('Helio Center', 7, change: RerouteStopChange.added),
        stop('Cầu Rồng', 8, change: RerouteStopChange.moved),
      ],
      removedStops: const ['Chợ Hàn'],
      affectedStops: const ['Chợ Hàn'],
      travelTimeDiffMinutes: travelTimeDiffMinutes,
      arrivalTimeDiffMinutes: arrivalTimeDiffMinutes,
      proposedAt: proposedAt,
      expiresAt: expiresAt ?? proposedAt.add(const Duration(minutes: 15)),
    );
  }
}
