import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/reroute_proposal.dart';

RerouteProposal _proposal({
  RerouteStatus status = RerouteStatus.pending,
  DateTime? expiresAt,
}) {
  final proposedAt = DateTime.utc(2026, 11, 25, 3);
  return RerouteProposal(
    proposalId: 7,
    incidentId: 42,
    status: status,
    reason: const RerouteReason(
      code: 'trip_alert.severe_weather',
      strategy: 'ReplaceWithIndoor',
      affectedPoiName: 'Han Market',
    ),
    currentStops: [
      RerouteStop(
        name: 'Han Market',
        plannedArrival: proposedAt,
        plannedDeparture: proposedAt.add(const Duration(hours: 1)),
      ),
    ],
    proposedStops: [
      RerouteStop(
        name: 'Helio Center',
        plannedArrival: proposedAt,
        plannedDeparture: proposedAt.add(const Duration(hours: 1)),
        change: RerouteStopChange.added,
      ),
    ],
    removedStops: const ['Han Market'],
    affectedStops: const ['Han Market'],
    travelTimeDiffMinutes: -15,
    arrivalTimeDiffMinutes: -30,
    proposedAt: proposedAt,
    expiresAt: expiresAt ?? proposedAt.add(const Duration(minutes: 15)),
  );
}

void main() {
  group('RerouteProposal', () {
    test('is actionable only while pending and before expiresAt', () {
      final proposal = _proposal();
      final before = DateTime.utc(2026, 11, 25, 3, 14, 59);
      final atExpiry = DateTime.utc(2026, 11, 25, 3, 15);

      expect(proposal.isActionableAt(before), isTrue);
      expect(proposal.isExpiredAt(atExpiry), isTrue);
      expect(proposal.isActionableAt(atExpiry), isFalse);
      expect(
        _proposal(status: RerouteStatus.accepted).isActionableAt(before),
        isFalse,
      );
      expect(
        _proposal(status: RerouteStatus.declined).isActionableAt(before),
        isFalse,
      );
    });

    test('copyWith changes the status and decision time only', () {
      final decidedAt = DateTime.utc(2026, 11, 25, 3, 5);
      final declined = _proposal().copyWith(
        status: RerouteStatus.declined,
        decidedAt: decidedAt,
      );

      expect(declined.status, RerouteStatus.declined);
      expect(declined.decidedAt, decidedAt);
      expect(declined.proposalId, 7);
      expect(declined.proposedStops, _proposal().proposedStops);
    });

    test('is value-equal when every field matches', () {
      expect(_proposal(), _proposal());
      expect(_proposal(), isNot(_proposal(status: RerouteStatus.expired)));
    });
  });
}
