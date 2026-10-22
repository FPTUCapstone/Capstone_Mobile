import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';

final class TripTourInfo extends Equatable {
  const TripTourInfo({required this.title, required this.destinationSummary});

  final String title;
  final String destinationSummary;

  @override
  List<Object?> get props => [title, destinationSummary];
}

final class TripScheduleInfo extends Equatable {
  const TripScheduleInfo({
    required this.startAtUtc,
    required this.endAtUtc,
    this.meetingPoint,
  });

  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String? meetingPoint;

  @override
  List<Object?> get props => [startAtUtc, endAtUtc, meetingPoint];
}

final class TripParticipantCounts extends Equatable {
  const TripParticipantCounts({
    required this.adult,
    required this.child,
    required this.infant,
  });

  final int adult;
  final int child;
  final int infant;

  @override
  List<Object?> get props => [adult, child, infant];
}

final class TripCancellationInfo extends Equatable {
  const TripCancellationInfo({this.cancelledAtUtc, this.reason});

  final DateTime? cancelledAtUtc;
  final String? reason;

  @override
  List<Object?> get props => [cancelledAtUtc, reason];
}

/// The latest refund of a cancelled booking.
final class TripRefundDetail extends Equatable {
  const TripRefundDetail({
    required this.status,
    required this.amount,
    this.channel,
  });

  /// The backend refund status text (`Processed`, `Pending`, ...).
  final String status;

  /// Whole VND.
  final int amount;

  /// The gateway of the original payment; null when it cannot be resolved.
  final String? channel;

  @override
  List<Object?> get props => [status, amount, channel];
}

enum TripVisitStatus { reached, skipped, pending }

final class TripStopDetail extends Equatable {
  const TripStopDetail({
    required this.sequenceNo,
    required this.poiId,
    required this.poiName,
    this.plannedArrivalUtc,
    this.plannedDepartureUtc,
    this.visitStatus,
    this.reachedAtUtc,
    this.skippedAtUtc,
  });

  final int sequenceNo;
  final int poiId;
  final String poiName;
  final DateTime? plannedArrivalUtc;
  final DateTime? plannedDepartureUtc;

  /// Present only for a Completed itinerary.
  final TripVisitStatus? visitStatus;
  final DateTime? reachedAtUtc;
  final DateTime? skippedAtUtc;

  @override
  List<Object?> get props => [
    sequenceNo,
    poiId,
    poiName,
    plannedArrivalUtc,
    plannedDepartureUtc,
    visitStatus,
    reachedAtUtc,
    skippedAtUtc,
  ];
}

final class TripSessionDetail extends Equatable {
  const TripSessionDetail({
    required this.startedAtUtc,
    this.endedAtUtc,
    this.completionReason,
  });

  final DateTime startedAtUtc;
  final DateTime? endedAtUtc;

  /// `RouteFinished`, `TravelerStopped` or `Expired`.
  final String? completionReason;

  @override
  List<Object?> get props => [startedAtUtc, endedAtUtc, completionReason];
}

sealed class TripRecordDetail extends Equatable {
  const TripRecordDetail();

  TripRecord get record;
}

final class BookingTripDetail extends TripRecordDetail {
  const BookingTripDetail({
    required this.record,
    required this.tour,
    required this.schedule,
    required this.participants,
    this.cancellation,
    this.refund,
  });

  @override
  final BookingTripRecord record;
  final TripTourInfo tour;
  final TripScheduleInfo schedule;
  final TripParticipantCounts participants;

  /// Only for a Cancelled booking.
  final TripCancellationInfo? cancellation;

  /// Only for a Cancelled booking that has a refund.
  final TripRefundDetail? refund;

  @override
  List<Object?> get props => [
    record,
    tour,
    schedule,
    participants,
    cancellation,
    refund,
  ];
}

final class ItineraryTripDetail extends TripRecordDetail {
  const ItineraryTripDetail({
    required this.record,
    required this.stops,
    this.validFromUtc,
    this.validToUtc,
    this.session,
  });

  @override
  final ItineraryTripRecord record;
  final DateTime? validFromUtc;
  final DateTime? validToUtc;
  final List<TripStopDetail> stops;

  /// Only for a Completed itinerary.
  final TripSessionDetail? session;

  @override
  List<Object?> get props => [record, validFromUtc, validToUtc, stops, session];
}
