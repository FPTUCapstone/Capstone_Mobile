import 'package:equatable/equatable.dart';

/// UC-09: the five optional travel preference dimensions used as soft
/// constraints by the itinerary planner. Every field may be unset
/// (`null`/empty list) for a Traveler who has never saved preferences.
final class TravelPreferences extends Equatable {
  const TravelPreferences({
    required this.interests,
    required this.preferredTransportMode,
    required this.travelPace,
    required this.riskTolerance,
    required this.foodPreferences,
    this.updatedAtUtc,
  });

  const TravelPreferences.empty()
    : this(
        interests: const [],
        preferredTransportMode: null,
        travelPace: null,
        riskTolerance: null,
        foodPreferences: const [],
      );

  final List<String> interests;
  final String? preferredTransportMode;
  final String? travelPace;
  final String? riskTolerance;
  final List<String> foodPreferences;
  final DateTime? updatedAtUtc;

  @override
  List<Object?> get props => [
    interests,
    preferredTransportMode,
    travelPace,
    riskTolerance,
    foodPreferences,
    updatedAtUtc,
  ];
}
