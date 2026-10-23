import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/reviewable_record_ref.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';

/// UC-32 Trip History record as returned by the TM-78 API.
///
/// A record is identified by the pair ([TripRecordKind], id); an id alone is
/// never meaningful. Nothing here is derived or defaulted on the device.

enum TripRecordKind {
  commerceBooking,
  itinerary;

  /// The value the backend uses in `kind` and in the detail path.
  String get wireKind => name;
}

final class TripRecordActions extends Equatable {
  const TripRecordActions({
    required this.canReview,
    required this.canViewETicket,
    required this.ticketId,
    required this.canViewRefund,
  });

  /// A Completed booking that has not been reviewed yet. Always false for itineraries.
  final bool canReview;
  final bool canViewETicket;

  /// The id for the UC-29 e-ticket; never the booking id.
  final int? ticketId;
  final bool canViewRefund;

  @override
  List<Object?> get props => [
    canReview,
    canViewETicket,
    ticketId,
    canViewRefund,
  ];
}

final class TripRecordReview extends Equatable {
  const TripRecordReview({required this.exists, this.reviewId, this.rating});

  final bool exists;
  final int? reviewId;
  final int? rating;

  @override
  List<Object?> get props => [exists, reviewId, rating];
}

/// The identity of a record: the pair (kind, id), never an id alone.
final class TripRecordRef extends Equatable {
  const TripRecordRef({required this.kind, required this.id}) : assert(id > 0);

  final TripRecordKind kind;
  final int id;

  @override
  List<Object?> get props => [kind, id];
}

sealed class TripRecord extends Equatable {
  const TripRecord({
    required this.id,
    required this.tab,
    required this.title,
    required this.departureAtUtc,
    required this.status,
    required this.actions,
  });

  final int id;
  final TripStatus tab;
  final String title;

  /// A UTC instant; display it with `TripFormatters.formatVietnamDate`.
  final DateTime departureAtUtc;

  /// The backend status text (`Completed`, `Confirmed`, `Active`, ...).
  final String status;
  final TripRecordActions actions;

  TripRecordKind get kind;
}

final class BookingTripRecord extends TripRecord {
  const BookingTripRecord({
    required super.id,
    required super.tab,
    required super.title,
    required super.departureAtUtc,
    required super.status,
    required super.actions,
    required this.bookingCode,
    required this.participantCount,
    required this.totalAmount,
    required this.reviewableRecord,
    required this.review,
  });

  final String bookingCode;
  final int participantCount;

  /// Whole VND.
  final int totalAmount;
  final ReviewableRecordRef reviewableRecord;
  final TripRecordReview review;

  @override
  TripRecordKind get kind => TripRecordKind.commerceBooking;

  @override
  List<Object?> get props => [
    id,
    tab,
    title,
    departureAtUtc,
    status,
    actions,
    bookingCode,
    participantCount,
    totalAmount,
    reviewableRecord,
    review,
  ];
}

final class ItineraryTripRecord extends TripRecord {
  const ItineraryTripRecord({
    required super.id,
    required super.tab,
    required super.title,
    required super.departureAtUtc,
    required super.status,
    required super.actions,
    required this.stopCount,
    this.visitedCount,
  });

  final int stopCount;

  /// Present only for a Completed itinerary.
  final int? visitedCount;

  @override
  TripRecordKind get kind => TripRecordKind.itinerary;

  @override
  List<Object?> get props => [
    id,
    tab,
    title,
    departureAtUtc,
    status,
    actions,
    stopCount,
    visitedCount,
  ];
}

final class TripRecordSummary extends Equatable {
  const TripRecordSummary({
    required this.totalCompletedTrips,
    required this.totalVisitedPois,
  });

  final int totalCompletedTrips;
  final int totalVisitedPois;

  @override
  List<Object?> get props => [totalCompletedTrips, totalVisitedPois];
}

final class TripRecordPage extends Equatable {
  const TripRecordPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    this.summary,
  });

  final List<TripRecord> items;

  /// Only on the Completed tab.
  final TripRecordSummary? summary;
  final int page;
  final int pageSize;
  final int totalCount;

  int get totalPages => (totalCount / pageSize).ceil().clamp(1, 1 << 20);

  @override
  List<Object?> get props => [items, summary, page, pageSize, totalCount];
}
