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
    required this.totalSlots,
    required this.availabilityStatus,
  });

  final String scheduleId;
  final DateTime departureAtUtc;
  final int price;
  final String currency;
  final int remainingSlots;
  final int totalSlots;
  final AvailabilityStatus availabilityStatus;

  bool get isSoldOut =>
      availabilityStatus == AvailabilityStatus.soldOut || remainingSlots <= 0;

  @override
  List<Object?> get props => [
    scheduleId,
    departureAtUtc,
    price,
    currency,
    remainingSlots,
    totalSlots,
    availabilityStatus,
  ];
}
