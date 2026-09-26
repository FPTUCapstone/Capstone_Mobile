import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';

final class TourSummary extends Equatable {
  const TourSummary({
    required this.tourId,
    required this.title,
    required this.destinations,
    required this.operatorName,
    required this.durationDays,
    required this.basePrice,
    required this.currency,
    required this.representativeScheduleId,
    required this.departureAtUtc,
    required this.availabilityStatus,
    required this.remainingSlots,
  });

  final String tourId;
  final String title;
  final List<String> destinations;
  final String operatorName;
  final int durationDays;
  final int basePrice;
  final String currency;
  final String? representativeScheduleId;
  final DateTime? departureAtUtc;
  final AvailabilityStatus availabilityStatus;
  final int? remainingSlots;

  @override
  List<Object?> get props => [
    tourId,
    title,
    destinations,
    operatorName,
    durationDays,
    basePrice,
    currency,
    representativeScheduleId,
    departureAtUtc,
    availabilityStatus,
    remainingSlots,
  ];
}
