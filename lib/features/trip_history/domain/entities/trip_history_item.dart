import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_enums.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_refund_info.dart';
import 'package:trip_mate_mobile/features/trip_history/domain/entities/trip_review.dart';

/// @deprecated Legacy model of the Trip History screen, kept only for the legacy review flow and
/// the bookings tab (`TripHistoryItem`). UC-32 (TM-78) uses `TripRecord`, `TripRecordsCubit` and
/// `TripRecordsRepository`; do not extend this type.
final class TripHistoryItem extends Equatable {
  const TripHistoryItem({
    required this.id,
    required this.bookingCode,
    required this.title,
    required this.type,
    required this.status,
    required this.departureDate,
    required this.participantsCount,
    required this.totalAmount,
    required this.travelerId,
    this.hasEticket = false,
    this.review,
    this.refundInfo,
    this.bookingId,
    this.itineraryId,
    this.providerName,
    this.location,
  });

  final String id;
  final String bookingCode;
  final String title;
  final TripType type;
  final TripStatus status;
  final DateTime departureDate;
  final int participantsCount;
  final int totalAmount; // in VND
  final int travelerId;
  final bool hasEticket;
  final TripReview? review;
  final TripRefundInfo? refundInfo;

  /// Authoritative numeric booking identifier supplied by a future production
  /// history endpoint. Demo-only trip IDs must never be used for refund APIs.
  final int? bookingId;
  final int? itineraryId;
  final String? providerName;
  final String? location;

  /// BR-91: The review action is offered only for a trip that has been completed.
  /// BR-92: The review action is offered only for a booking that has not been reviewed yet.
  /// Self-planned itineraries do not have third-party bookings to review.
  bool get canWriteReview =>
      status == TripStatus.completed &&
      type != TripType.itinerary &&
      review == null;

  /// BR-95: A published review may be edited within 7 days.
  bool canEditReview([DateTime? referenceTime]) =>
      status == TripStatus.completed &&
      type != TripType.itinerary &&
      review != null &&
      review!.isEditable(referenceTime);

  /// Review exists and has surpassed the 7-day edit window.
  bool isReadOnlyReview([DateTime? referenceTime]) =>
      status == TripStatus.completed &&
      type != TripType.itinerary &&
      review != null &&
      !review!.isEditable(referenceTime);

  /// A refund can be tracked only when the history record has both evidence of
  /// a refund and the real booking identifier required by the Backend API.
  bool get canViewRefundStatus =>
      status == TripStatus.cancelled && refundInfo != null && bookingId != null;

  /// Self-planned itineraries or linked itineraries can navigate to details.
  bool get isItinerary => type == TripType.itinerary;

  @override
  List<Object?> get props => [
    id,
    bookingCode,
    title,
    type,
    status,
    departureDate,
    participantsCount,
    totalAmount,
    travelerId,
    hasEticket,
    review,
    refundInfo,
    bookingId,
    itineraryId,
    providerName,
    location,
  ];
}
