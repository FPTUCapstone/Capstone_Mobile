import 'package:equatable/equatable.dart';

/// A single selectable interest key sourced from the Backend's POI
/// category/tag catalogue (UC-09); never a Mobile-hardcoded enum.
final class InterestOption extends Equatable {
  const InterestOption({required this.key, required this.source});

  final String key;
  final String source;

  @override
  List<Object?> get props => [key, source];
}

/// The catalogue of selectable values for every UC-09 preference field,
/// as returned by `GET /api/v1/traveler/preferences/options`. Interests are
/// dynamic (database-backed); the other four lists are the Backend's
/// current enum names and may change independently of this client.
final class TravelPreferenceOptions extends Equatable {
  const TravelPreferenceOptions({
    required this.interests,
    required this.preferredTransportModes,
    required this.travelPaces,
    required this.foodPreferences,
    required this.riskTolerances,
  });

  const TravelPreferenceOptions.empty()
    : this(
        interests: const [],
        preferredTransportModes: const [],
        travelPaces: const [],
        foodPreferences: const [],
        riskTolerances: const [],
      );

  final List<InterestOption> interests;
  final List<String> preferredTransportModes;
  final List<String> travelPaces;
  final List<String> foodPreferences;
  final List<String> riskTolerances;

  @override
  List<Object?> get props => [
    interests,
    preferredTransportModes,
    travelPaces,
    foodPreferences,
    riskTolerances,
  ];
}
