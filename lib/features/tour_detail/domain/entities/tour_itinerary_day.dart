import 'package:equatable/equatable.dart';

/// Represents a single day in a tour's published itinerary.
final class TourItineraryDay extends Equatable {
  const TourItineraryDay({
    required this.dayNumber,
    required this.title,
    required this.description,
    this.activities = const [],
  });

  final int dayNumber;
  final String title;
  final String description;
  final List<String> activities;

  @override
  List<Object?> get props => [dayNumber, title, description, activities];
}
