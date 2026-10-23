import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';

/// DEMO ONLY. Trip History records in the TM-78 contract shape, served when the
/// route is opened in a debug build with `demo=true`. Never a production path
/// and never a fallback after a real request fails.
abstract final class DemoTripRecordsData {
  static const _noActions = TripRecordActions(
    canReview: false,
    canViewETicket: false,
    ticketId: null,
    canViewRefund: false,
  );

  static BookingTripDetail _booking({
    required int id,
    required TripStatus tab,
    required String title,
    required DateTime departure,
    required String status,
    required int participantCount,
    required int totalAmount,
    required TripRecordActions actions,
    required TripTourInfo tour,
    required TripScheduleInfo schedule,
    required TripParticipantCounts participants,
    TripRecordReview review = const TripRecordReview(exists: false),
    TripCancellationInfo? cancellation,
    TripRefundDetail? refund,
  }) => BookingTripDetail(
    record: BookingTripRecord(
      id: id,
      tab: tab,
      title: title,
      departureAtUtc: departure,
      status: status,
      actions: actions,
      bookingCode: 'TM-${id.toString().padLeft(6, '0')}',
      participantCount: participantCount,
      totalAmount: totalAmount,
      reviewableRecord: ReviewableRecordRef(
        kind: ReviewableRecordKind.commerceBooking,
        id: id,
      ),
      review: review,
    ),
    tour: tour,
    schedule: schedule,
    participants: participants,
    cancellation: cancellation,
    refund: refund,
  );

  static ItineraryTripDetail _itinerary({
    required int id,
    required TripStatus tab,
    required String title,
    required DateTime departure,
    required String status,
    required List<TripStopDetail> stops,
    DateTime? validFrom,
    DateTime? validTo,
    TripSessionDetail? session,
  }) => ItineraryTripDetail(
    record: ItineraryTripRecord(
      id: id,
      tab: tab,
      title: title,
      departureAtUtc: departure,
      status: status,
      actions: _noActions,
      stopCount: stops.length,
      visitedCount: tab == TripStatus.completed
          ? stops.where((s) => s.visitStatus == TripVisitStatus.reached).length
          : null,
    ),
    stops: stops,
    validFromUtc: validFrom,
    validToUtc: validTo,
    session: session,
  );

  static TripStopDetail _stop(
    int sequenceNo,
    int poiId,
    String name,
    DateTime arrival,
    DateTime departure, [
    TripVisitStatus? visit,
    DateTime? at,
  ]) => TripStopDetail(
    sequenceNo: sequenceNo,
    poiId: poiId,
    poiName: name,
    plannedArrivalUtc: arrival,
    plannedDepartureUtc: departure,
    visitStatus: visit,
    reachedAtUtc: visit == TripVisitStatus.reached ? at : null,
    skippedAtUtc: visit == TripVisitStatus.skipped ? at : null,
  );

  static final List<TripRecordDetail> details = List.unmodifiable([
    _booking(
      id: 9001,
      tab: TripStatus.completed,
      title: 'Hoi An Lantern Tour',
      departure: DateTime.utc(2026, 10, 1, 2),
      status: 'Completed',
      participantCount: 3,
      totalAmount: 4500000,
      actions: const TripRecordActions(
        canReview: true,
        canViewETicket: true,
        ticketId: 7001,
        canViewRefund: false,
      ),
      tour: const TripTourInfo(
        title: 'Hoi An Lantern Tour',
        destinationSummary: 'Hoi An',
      ),
      schedule: TripScheduleInfo(
        startAtUtc: DateTime.utc(2026, 10, 1, 2),
        endAtUtc: DateTime.utc(2026, 10, 1, 10),
        meetingPoint: 'Old Town gate',
      ),
      participants: const TripParticipantCounts(adult: 2, child: 1, infant: 0),
    ),
    _booking(
      id: 9002,
      tab: TripStatus.completed,
      title: 'Ba Na Hills Day Tour',
      departure: DateTime.utc(2026, 9, 20, 1),
      status: 'Completed',
      participantCount: 2,
      totalAmount: 3200000,
      actions: const TripRecordActions(
        canReview: false,
        canViewETicket: true,
        ticketId: 7002,
        canViewRefund: false,
      ),
      review: const TripRecordReview(exists: true, reviewId: 8001, rating: 5),
      tour: const TripTourInfo(
        title: 'Ba Na Hills Day Tour',
        destinationSummary: 'Da Nang',
      ),
      schedule: TripScheduleInfo(
        startAtUtc: DateTime.utc(2026, 9, 20, 1),
        endAtUtc: DateTime.utc(2026, 9, 20, 9),
      ),
      participants: const TripParticipantCounts(adult: 2, child: 0, infant: 0),
    ),
    _booking(
      id: 9003,
      tab: TripStatus.upcoming,
      title: 'Son Tra Peninsula Tour',
      departure: DateTime.utc(2027, 1, 15, 1),
      status: 'Confirmed',
      participantCount: 2,
      totalAmount: 2400000,
      actions: const TripRecordActions(
        canReview: false,
        canViewETicket: true,
        ticketId: 7003,
        canViewRefund: false,
      ),
      tour: const TripTourInfo(
        title: 'Son Tra Peninsula Tour',
        destinationSummary: 'Da Nang',
      ),
      schedule: TripScheduleInfo(
        startAtUtc: DateTime.utc(2027, 1, 15, 1),
        endAtUtc: DateTime.utc(2027, 1, 15, 8),
        meetingPoint: 'Han River Bridge',
      ),
      participants: const TripParticipantCounts(adult: 2, child: 0, infant: 0),
    ),
    _booking(
      id: 9004,
      tab: TripStatus.cancelled,
      title: 'My Son Sanctuary Tour',
      departure: DateTime.utc(2026, 8, 20, 1),
      status: 'Cancelled',
      participantCount: 2,
      totalAmount: 1600000,
      actions: const TripRecordActions(
        canReview: false,
        canViewETicket: false,
        ticketId: null,
        canViewRefund: true,
      ),
      tour: const TripTourInfo(
        title: 'My Son Sanctuary Tour',
        destinationSummary: 'Quang Nam',
      ),
      schedule: TripScheduleInfo(
        startAtUtc: DateTime.utc(2026, 8, 20, 1),
        endAtUtc: DateTime.utc(2026, 8, 20, 9),
        meetingPoint: 'Hotel lobby',
      ),
      participants: const TripParticipantCounts(adult: 2, child: 0, infant: 0),
      cancellation: TripCancellationInfo(
        cancelledAtUtc: DateTime.utc(2026, 8, 10, 3),
        reason: 'Change of plans',
      ),
      refund: const TripRefundDetail(
        status: 'Processed',
        amount: 800000,
        channel: 'PayOS',
      ),
    ),
    _booking(
      id: 9005,
      tab: TripStatus.cancelled,
      title: 'Marble Mountains Tour',
      departure: DateTime.utc(2026, 7, 5, 1),
      status: 'Expired',
      participantCount: 1,
      totalAmount: 700000,
      actions: _noActions,
      tour: const TripTourInfo(
        title: 'Marble Mountains Tour',
        destinationSummary: 'Da Nang',
      ),
      schedule: TripScheduleInfo(
        startAtUtc: DateTime.utc(2026, 7, 5, 1),
        endAtUtc: DateTime.utc(2026, 7, 5, 5),
      ),
      participants: const TripParticipantCounts(adult: 1, child: 0, infant: 0),
    ),
    _itinerary(
      id: 5001,
      tab: TripStatus.completed,
      title: 'Da Nang 2 days',
      departure: DateTime.utc(2026, 9, 20, 1),
      status: 'Completed',
      validFrom: DateTime.utc(2026, 9, 19),
      validTo: DateTime.utc(2026, 9, 22),
      stops: [
        _stop(
          1,
          101,
          'Dragon Bridge',
          DateTime.utc(2026, 9, 20, 1),
          DateTime.utc(2026, 9, 20, 2),
          TripVisitStatus.reached,
          DateTime.utc(2026, 9, 20, 1, 5),
        ),
        _stop(
          2,
          102,
          'My Khe Beach',
          DateTime.utc(2026, 9, 20, 2, 30),
          DateTime.utc(2026, 9, 20, 4),
          TripVisitStatus.reached,
          DateTime.utc(2026, 9, 20, 2, 40),
        ),
        _stop(
          3,
          103,
          'Han Market',
          DateTime.utc(2026, 9, 20, 4, 30),
          DateTime.utc(2026, 9, 20, 5, 30),
          TripVisitStatus.skipped,
          DateTime.utc(2026, 9, 20, 4, 35),
        ),
        _stop(
          4,
          104,
          'Marble Mountains',
          DateTime.utc(2026, 9, 20, 6),
          DateTime.utc(2026, 9, 20, 8),
          TripVisitStatus.reached,
          DateTime.utc(2026, 9, 20, 6, 10),
        ),
      ],
      session: TripSessionDetail(
        startedAtUtc: DateTime.utc(2026, 9, 20, 1),
        endedAtUtc: DateTime.utc(2026, 9, 20, 9, 30),
        completionReason: 'RouteFinished',
      ),
    ),
    _itinerary(
      id: 5002,
      tab: TripStatus.completed,
      title: 'Hue day trip',
      departure: DateTime.utc(2026, 8, 2, 2),
      status: 'Completed',
      stops: [
        _stop(
          1,
          201,
          'Imperial City',
          DateTime.utc(2026, 8, 2, 2),
          DateTime.utc(2026, 8, 2, 4),
          TripVisitStatus.reached,
          DateTime.utc(2026, 8, 2, 2, 10),
        ),
        _stop(
          2,
          202,
          'Thien Mu Pagoda',
          DateTime.utc(2026, 8, 2, 4, 30),
          DateTime.utc(2026, 8, 2, 5, 30),
          TripVisitStatus.pending,
        ),
        _stop(
          3,
          203,
          'Khai Dinh Tomb',
          DateTime.utc(2026, 8, 2, 6),
          DateTime.utc(2026, 8, 2, 7, 30),
          TripVisitStatus.pending,
        ),
      ],
      session: TripSessionDetail(
        startedAtUtc: DateTime.utc(2026, 8, 2, 2),
        endedAtUtc: DateTime.utc(2026, 8, 2, 14),
        completionReason: 'Expired',
      ),
    ),
    _itinerary(
      id: 5003,
      tab: TripStatus.upcoming,
      title: 'Hoi An weekend plan',
      departure: DateTime.utc(2026, 12, 1, 1),
      status: 'Active',
      validFrom: DateTime.utc(2026, 12, 1),
      validTo: DateTime.utc(2026, 12, 3),
      stops: [
        _stop(
          1,
          301,
          'Japanese Covered Bridge',
          DateTime.utc(2026, 12, 1, 1),
          DateTime.utc(2026, 12, 1, 2),
        ),
        _stop(
          2,
          302,
          'An Bang Beach',
          DateTime.utc(2026, 12, 1, 3),
          DateTime.utc(2026, 12, 1, 5),
        ),
        _stop(
          3,
          303,
          'Tra Que Vegetable Village',
          DateTime.utc(2026, 12, 2, 1),
          DateTime.utc(2026, 12, 2, 3),
        ),
      ],
    ),
    _itinerary(
      id: 5004,
      tab: TripStatus.cancelled,
      title: 'Ngu Hanh Son plan',
      departure: DateTime.utc(2026, 6, 10, 1),
      status: 'Cancelled',
      stops: [
        _stop(
          1,
          401,
          'Marble Mountains',
          DateTime.utc(2026, 6, 10, 1),
          DateTime.utc(2026, 6, 10, 3),
        ),
        _stop(
          2,
          402,
          'Non Nuoc Beach',
          DateTime.utc(2026, 6, 10, 4),
          DateTime.utc(2026, 6, 10, 6),
        ),
      ],
    ),
  ]);
}
