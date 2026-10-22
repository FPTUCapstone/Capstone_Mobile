import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/trip_history/resources/trip_history_en.dart';

void main() {
  group('TM-78 trip detail strings', () {
    final values = <String>[
      TripHistoryStringsEn.detailLoading,
      TripHistoryStringsEn.tourSectionTitle,
      TripHistoryStringsEn.labelDestination,
      TripHistoryStringsEn.scheduleSectionTitle,
      TripHistoryStringsEn.labelStarts,
      TripHistoryStringsEn.labelEnds,
      TripHistoryStringsEn.labelMeetingPoint,
      TripHistoryStringsEn.participantsSectionTitle,
      TripHistoryStringsEn.formatAdults(2),
      TripHistoryStringsEn.formatChildren(2),
      TripHistoryStringsEn.formatInfants(2),
      TripHistoryStringsEn.cancellationSectionTitle,
      TripHistoryStringsEn.labelCancelledOn,
      TripHistoryStringsEn.labelCancelReason,
      TripHistoryStringsEn.refundSectionTitle,
      TripHistoryStringsEn.labelRefundAmount,
      TripHistoryStringsEn.labelRefundChannel,
      TripHistoryStringsEn.channelUnavailable,
      TripHistoryStringsEn.stopsSectionTitle,
      TripHistoryStringsEn.stopVisited,
      TripHistoryStringsEn.stopSkipped,
      TripHistoryStringsEn.stopNotVisited,
      TripHistoryStringsEn.formatReachedAt('01/10/2026 09:00'),
      TripHistoryStringsEn.formatSkippedAt('01/10/2026 09:00'),
      TripHistoryStringsEn.formatPlannedWindow('08:00', '09:00'),
      TripHistoryStringsEn.formatVisitedOf(3, 4),
      TripHistoryStringsEn.sessionSectionTitle,
      TripHistoryStringsEn.labelSessionStarted,
      TripHistoryStringsEn.labelSessionEnded,
      TripHistoryStringsEn.labelSessionReason,
      TripHistoryStringsEn.tripRecordUnavailable,
      TripHistoryStringsEn.summaryCompletedTrips(14),
      TripHistoryStringsEn.summaryVisitedPois(63),
    ];

    test('are non-empty English copy without BR or MSG codes', () {
      for (final value in values) {
        expect(value.trim(), isNotEmpty);
        expect(value, isNot(matches(RegExp(r'\b(BR|MSG)-?\d+\b'))));
      }
    });

    test('pluralise participant counts', () {
      expect(TripHistoryStringsEn.formatAdults(1), '1 adult');
      expect(TripHistoryStringsEn.formatAdults(2), '2 adults');
      expect(TripHistoryStringsEn.formatChildren(1), '1 child');
      expect(TripHistoryStringsEn.formatChildren(3), '3 children');
      expect(TripHistoryStringsEn.formatInfants(1), '1 infant');
      expect(TripHistoryStringsEn.formatInfants(2), '2 infants');
    });

    test('name the visit and refund states readably', () {
      expect(TripHistoryStringsEn.refundStatusLabel('Processed'), 'Refunded');
      expect(TripHistoryStringsEn.refundStatusLabel('Pending'), 'Pending');
      expect(
        TripHistoryStringsEn.refundStatusLabel('ManualReview'),
        'Under review',
      );
      expect(TripHistoryStringsEn.refundStatusLabel('Mystery'), 'Mystery');
      expect(
        TripHistoryStringsEn.completionReasonLabel('RouteFinished'),
        'Route completed',
      );
      expect(
        TripHistoryStringsEn.completionReasonLabel('TravelerStopped'),
        'Stopped by you',
      );
      expect(
        TripHistoryStringsEn.completionReasonLabel('Expired'),
        'Ended automatically when the trip time ran out',
      );
      expect(TripHistoryStringsEn.completionReasonLabel('Mystery'), 'Mystery');
    });
  });
}
