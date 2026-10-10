import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_itinerary_day.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_review_item.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_schedule_item.dart';

/// Full domain entity for a Tour Details view (UC-26).
final class TourDetail extends Equatable {
  const TourDetail({
    required this.tourId,
    required this.title,
    required this.description,
    required this.destinations,
    required this.durationDays,
    required this.operatorName,
    this.operatorPhone,
    this.operatorEmail,
    required this.basePrice,
    required this.currency,
    this.images = const [],
    this.inclusions = const [],
    this.exclusions = const [],
    required this.cancellationPolicy,
    this.itineraryDays = const [],
    this.schedules = const [],
    this.reviews = const [],
    this.averageRating,
    this.reviewCount = 0,
  });

  final String tourId;
  final String title;
  final String description;
  final List<String> destinations;
  final int durationDays;
  final String operatorName;
  final String? operatorPhone;
  final String? operatorEmail;
  final int basePrice;
  final String currency;
  final List<String> images;
  final List<String> inclusions;
  final List<String> exclusions;
  final String cancellationPolicy;
  final List<TourItineraryDay> itineraryDays;
  final List<TourScheduleItem> schedules;
  final List<TourReviewItem> reviews;
  final double? averageRating;
  final int reviewCount;

  @override
  List<Object?> get props => [
    tourId,
    title,
    description,
    destinations,
    durationDays,
    operatorName,
    operatorPhone,
    operatorEmail,
    basePrice,
    currency,
    images,
    inclusions,
    exclusions,
    cancellationPolicy,
    itineraryDays,
    schedules,
    reviews,
    averageRating,
    reviewCount,
  ];
}
