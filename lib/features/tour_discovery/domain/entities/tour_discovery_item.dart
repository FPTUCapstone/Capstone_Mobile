import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/availability_status.dart';
import 'package:trip_mate_mobile/features/tour_search/domain/entities/tour_summary.dart';

/// Presentation entity for Tour Discovery (SRS #44, #63, #64) mapping cleanly
/// to production [TourSummary].
class TourDiscoveryItem extends Equatable {
  const TourDiscoveryItem({
    required this.id,
    required this.title,
    required this.destinations,
    required this.operatorName,
    required this.durationDays,
    required this.priceVnd,
    this.rating,
    this.imageUrl,
    this.availabilityStatus = AvailabilityStatus.available,
    this.remainingSlots,
    this.departureAtUtc,
    this.isCuratedAsset = false,
  });

  factory TourDiscoveryItem.fromSummary(TourSummary summary) {
    return TourDiscoveryItem(
      id: summary.tourId,
      title: summary.title,
      destinations: summary.destinations.join(' · '),
      operatorName: summary.operatorName,
      durationDays: summary.durationDays,
      priceVnd: summary.basePrice,
      rating: summary.aggregateRating,
      imageUrl: summary.thumbnailUrl,
      availabilityStatus: summary.availabilityStatus,
      remainingSlots: summary.remainingSlots,
      departureAtUtc: summary.departureAtUtc,
      isCuratedAsset: false,
    );
  }

  final String id;
  final String title;
  final String destinations;
  final String operatorName;
  final int durationDays;
  final int priceVnd;
  final double? rating;
  final String? imageUrl;
  final AvailabilityStatus availabilityStatus;
  final int? remainingSlots;
  final DateTime? departureAtUtc;
  final bool isCuratedAsset;

  TourSummary toSummary() {
    return TourSummary(
      tourId: id,
      title: title,
      destinations: destinations.split(' · '),
      operatorName: operatorName,
      durationDays: durationDays,
      basePrice: priceVnd,
      currency: 'VND',
      representativeScheduleId: null,
      departureAtUtc: departureAtUtc,
      availabilityStatus: availabilityStatus,
      remainingSlots: remainingSlots,
      thumbnailUrl: imageUrl,
      aggregateRating: rating,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    destinations,
    operatorName,
    durationDays,
    priceVnd,
    rating,
    imageUrl,
    availabilityStatus,
    remainingSlots,
    departureAtUtc,
    isCuratedAsset,
  ];
}
