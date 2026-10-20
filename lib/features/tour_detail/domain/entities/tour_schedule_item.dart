import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';

/// Represents a specific departure schedule option for a tour.
final class TourScheduleItem extends Equatable {
  const TourScheduleItem({
    required this.scheduleId,
    required this.departureAtUtc,
    required this.price,
    required this.currency,
    required this.remainingSlots,
    this.totalSlots,
    required this.availabilityStatus,
    this.endAtUtc,
    this.meetingPoint,
    this.registrationDeadlineUtc,
    this.childPrice,
    this.infantPrice,
    this.bookable,
  });

  final String scheduleId;
  final DateTime departureAtUtc;
  final int price;
  final String currency;

  /// Null when the Backend does not know the capacity.
  final int? remainingSlots;
  final int? totalSlots;
  final AvailabilityStatus availabilityStatus;
  final DateTime? endAtUtc;
  final String? meetingPoint;
  final DateTime? registrationDeadlineUtc;
  final int? childPrice;
  final int? infantPrice;

  /// Server decision: capacity left and registration still open. Null for data
  /// that does not carry it (demo fixtures); callers then fall back to [isSoldOut].
  final bool? bookable;

  bool get isSoldOut =>
      availabilityStatus == AvailabilityStatus.soldOut ||
      (remainingSlots != null && remainingSlots! <= 0);

  /// Whether a traveler may choose this departure for booking (BR-60).
  bool get isSelectable => bookable ?? !isSoldOut;

  @override
  List<Object?> get props => [
    scheduleId,
    departureAtUtc,
    price,
    currency,
    remainingSlots,
    totalSlots,
    availabilityStatus,
    endAtUtc,
    meetingPoint,
    registrationDeadlineUtc,
    childPrice,
    infantPrice,
    bookable,
  ];
}
