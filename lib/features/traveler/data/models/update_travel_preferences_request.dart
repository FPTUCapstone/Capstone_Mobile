/// `PUT /api/v1/traveler/preferences` body (UC-09 spec §4). Always the full
/// five-field state: an empty collection serializes as `[]`, an unset
/// scalar as `null`. No user ID, role, or legacy field (budget/travel
/// style/auto-apply) is ever present.
final class UpdateTravelPreferencesRequest {
  const UpdateTravelPreferencesRequest({
    required this.interests,
    required this.preferredTransportMode,
    required this.travelPace,
    required this.riskTolerance,
    required this.foodPreferences,
  });

  final List<String> interests;
  final String? preferredTransportMode;
  final String? travelPace;
  final String? riskTolerance;
  final List<String> foodPreferences;

  Map<String, dynamic> toJson() => {
    'interests': interests,
    'preferredTransportMode': preferredTransportMode,
    'travelPace': travelPace,
    'riskTolerance': riskTolerance,
    'foodPreferences': foodPreferences,
  };
}
