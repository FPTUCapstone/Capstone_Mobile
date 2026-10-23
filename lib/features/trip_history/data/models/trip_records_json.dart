import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_record_detail.dart';

/// Strict mapping of the TM-78 Trip History bodies to domain entities.
///
/// Anything that does not match the contract throws a [FormatException]; the
/// repository turns that into a safe failure. Unknown properties are ignored.
abstract final class TripRecordsJson {
  static TripRecordPage page(Object? json) {
    final source = _map(json);
    final summary = source['summary'];
    return TripRecordPage(
      items: _list(source['items']).map(_record).toList(growable: false),
      summary: summary == null ? null : _summary(summary),
      page: _int(source['page'], min: 1),
      pageSize: _int(source['pageSize'], min: 1),
      totalCount: _int(source['totalCount'], min: 0),
    );
  }

  static TripRecordDetail detail(Object? json) {
    final source = _map(json);
    final record = _record(source);
    switch (record) {
      case BookingTripRecord():
        final cancellation = source['cancellation'];
        final refund = source['refund'];
        return BookingTripDetail(
          record: record,
          tour: _tour(source['tour']),
          schedule: _schedule(source['schedule']),
          participants: _participants(source['participants']),
          cancellation: cancellation == null
              ? null
              : _cancellation(cancellation),
          refund: refund == null ? null : _refund(refund),
        );
      case ItineraryTripRecord():
        final session = source['session'];
        return ItineraryTripDetail(
          record: record,
          validFromUtc: _optionalInstant(source['validFromUtc']),
          validToUtc: _optionalInstant(source['validToUtc']),
          stops: _list(source['stops']).map(_stop).toList(growable: false),
          session: session == null ? null : _session(session),
        );
    }
  }

  static TripRecord _record(Object? value) {
    final source = _map(value);
    return switch (source['kind']) {
      'commerceBooking' => _booking(source),
      'itinerary' => _itinerary(source),
      _ => throw const FormatException('Unknown trip record kind.'),
    };
  }

  static BookingTripRecord _booking(Map<String, dynamic> source) {
    final id = _id(source['id']);
    if (source['tripType'] != 'TourBooking') _fail();
    final reference = _map(source['reviewableRecord']);
    if (reference['kind'] != 'commerceBooking' || _id(reference['id']) != id) {
      _fail();
    }
    return BookingTripRecord(
      id: id,
      tab: _tab(source['tab']),
      title: _text(source['title']),
      departureAtUtc: _instant(source['departureAtUtc']),
      status: _text(source['status']),
      actions: _actions(source['actions']),
      bookingCode: _text(source['bookingCode']),
      participantCount: _int(source['participantCount'], min: 0),
      totalAmount: _money(source['totalAmount']),
      reviewableRecord: ReviewableRecordRef(
        kind: ReviewableRecordKind.commerceBooking,
        id: id,
      ),
      review: _review(source['review']),
    );
  }

  static ItineraryTripRecord _itinerary(Map<String, dynamic> source) {
    if (source['tripType'] != 'SelfPlannedItinerary') _fail();
    if (source['reviewableRecord'] != null || source['review'] != null) {
      _fail();
    }
    final stopCount = _int(source['stopCount'], min: 0);
    final visited = source['visitedCount'];
    final visitedCount = visited == null ? null : _int(visited, min: 0);
    if (visitedCount != null && visitedCount > stopCount) _fail();
    return ItineraryTripRecord(
      id: _id(source['id']),
      tab: _tab(source['tab']),
      title: _text(source['title']),
      departureAtUtc: _instant(source['departureAtUtc']),
      status: _text(source['status']),
      actions: _actions(source['actions']),
      stopCount: stopCount,
      visitedCount: visitedCount,
    );
  }

  static TripRecordActions _actions(Object? value) {
    final source = _map(value);
    final ticketId = source['ticketId'];
    return TripRecordActions(
      canReview: _bool(source['canReview']),
      canViewETicket: _bool(source['canViewETicket']),
      ticketId: ticketId == null ? null : _id(ticketId),
      canViewRefund: _bool(source['canViewRefund']),
    );
  }

  static TripRecordReview _review(Object? value) {
    final source = _map(value);
    if (!_bool(source['exists'])) return const TripRecordReview(exists: false);
    final rating = _int(source['rating'], min: 1);
    if (rating > 5) _fail();
    return TripRecordReview(
      exists: true,
      reviewId: _id(source['reviewId']),
      rating: rating,
    );
  }

  static TripRecordSummary _summary(Object? value) {
    final source = _map(value);
    return TripRecordSummary(
      totalCompletedTrips: _int(source['totalCompletedTrips'], min: 0),
      totalVisitedPois: _int(source['totalVisitedPois'], min: 0),
    );
  }

  static TripTourInfo _tour(Object? value) {
    final source = _map(value);
    return TripTourInfo(
      title: _text(source['title']),
      destinationSummary: _text(source['destinationSummary']),
    );
  }

  static TripScheduleInfo _schedule(Object? value) {
    final source = _map(value);
    return TripScheduleInfo(
      startAtUtc: _instant(source['startAtUtc']),
      endAtUtc: _instant(source['endAtUtc']),
      meetingPoint: _optionalText(source['meetingPoint']),
    );
  }

  static TripParticipantCounts _participants(Object? value) {
    final source = _map(value);
    return TripParticipantCounts(
      adult: _int(source['adult'], min: 0),
      child: _int(source['child'], min: 0),
      infant: _int(source['infant'], min: 0),
    );
  }

  static TripCancellationInfo _cancellation(Object? value) {
    final source = _map(value);
    return TripCancellationInfo(
      cancelledAtUtc: _optionalInstant(source['cancelledAtUtc']),
      reason: _optionalText(source['reason']),
    );
  }

  static TripRefundDetail _refund(Object? value) {
    final source = _map(value);
    return TripRefundDetail(
      status: _text(source['status']),
      amount: _money(source['amount']),
      channel: _optionalText(source['channel']),
    );
  }

  static TripStopDetail _stop(Object? value) {
    final source = _map(value);
    final visit = source['visitStatus'];
    return TripStopDetail(
      sequenceNo: _int(source['sequenceNo'], min: 1),
      poiId: _id(source['poiId']),
      poiName: _text(source['poiName']),
      plannedArrivalUtc: _optionalInstant(source['plannedArrivalUtc']),
      plannedDepartureUtc: _optionalInstant(source['plannedDepartureUtc']),
      visitStatus: visit == null ? null : _visitStatus(visit),
      reachedAtUtc: _optionalInstant(source['reachedAtUtc']),
      skippedAtUtc: _optionalInstant(source['skippedAtUtc']),
    );
  }

  static TripVisitStatus _visitStatus(Object? value) => switch (value) {
    'Reached' => TripVisitStatus.reached,
    'Skipped' => TripVisitStatus.skipped,
    'Pending' => TripVisitStatus.pending,
    _ => throw const FormatException('Unknown stop visit status.'),
  };

  static TripSessionDetail _session(Object? value) {
    final source = _map(value);
    return TripSessionDetail(
      startedAtUtc: _instant(source['startedAtUtc']),
      endedAtUtc: _optionalInstant(source['endedAtUtc']),
      completionReason: _optionalText(source['completionReason']),
    );
  }

  static TripStatus _tab(Object? value) => switch (value) {
    'Upcoming' => TripStatus.upcoming,
    'Completed' => TripStatus.completed,
    'Cancelled' => TripStatus.cancelled,
    _ => throw const FormatException('Unknown trip tab.'),
  };

  static Never _fail() =>
      throw const FormatException('The trip history body breaks the contract.');

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : _fail();

  static List<Object?> _list(Object? value) =>
      value is List<Object?> ? value : _fail();

  static String _text(Object? value) => value is String ? value : _fail();

  static String? _optionalText(Object? value) =>
      value == null ? null : _text(value);

  static bool _bool(Object? value) => value is bool ? value : _fail();

  /// A whole number at or above [min]; a fractional value is rejected, not rounded.
  static int _int(Object? value, {required int min}) {
    if (value is! int || value < min) _fail();
    return value;
  }

  /// A positive identity. Dart ints are 64-bit on device, so the value is exact.
  static int _id(Object? value) => _int(value, min: 1);

  /// Whole VND; the backend sends a decimal such as `3200000.00`.
  static int _money(Object? value) {
    if (value is! num || value < 0 || !value.isFinite) _fail();
    return value.round();
  }

  static DateTime _instant(Object? value) =>
      DateTime.parse(_text(value)).toUtc();

  static DateTime? _optionalInstant(Object? value) =>
      value == null ? null : _instant(value);
}
