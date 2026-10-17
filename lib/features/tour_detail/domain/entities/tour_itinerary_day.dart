import 'package:equatable/equatable.dart';
import 'package:trip_mate_mobile/features/tour_detail/domain/entities/tour_itinerary_stop.dart';

/// Represents a single day in a tour's published itinerary.
final class TourItineraryDay extends Equatable {
  const TourItineraryDay({
    required this.dayNumber,
    required this.title,
    required this.description,
    this.activities = const [],
    this.stops = const [],
  });

  final int dayNumber;
  final String title;
  final String description;
  final List<String> activities;

  /// Structured stops from the published itinerary; empty for free-text days.
  final List<TourItineraryStop> stops;

  @override
  List<Object?> get props => [dayNumber, title, description, activities, stops];
}
