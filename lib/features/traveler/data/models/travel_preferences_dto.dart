/// `GET`/`PUT /api/v1/traveler/preferences` response (UC-09). Returned
/// directly by the controller with no `{ success, data }` envelope. Every
/// scalar field may be `null` and every list field may be empty for a
/// Traveler who has not saved that value.
final class TravelPreferencesDto {
  const TravelPreferencesDto({
    required this.interests,
    required this.preferredTransportMode,
    required this.travelPace,
    required this.riskTolerance,
    required this.foodPreferences,
    required this.updatedAtUtc,
  });

  factory TravelPreferencesDto.fromJson(Map<String, dynamic> json) {
    final interests = json['interests'];
    final foodPreferences = json['foodPreferences'];
    if (interests is! List || foodPreferences is! List) {
      throw const FormatException('Invalid travel preferences response.');
    }

    final updatedAtUtcRaw = json['updatedAtUtc'];
    final updatedAtUtc = updatedAtUtcRaw is String
        ? DateTime.tryParse(updatedAtUtcRaw)
        : null;

    return TravelPreferencesDto(
      interests: interests
          .map((item) => item as String)
          .toList(growable: false),
      preferredTransportMode: json['preferredTransportMode'] as String?,
      travelPace: json['travelPace'] as String?,
      riskTolerance: json['riskTolerance'] as String?,
      foodPreferences: foodPreferences
          .map((item) => item as String)
          .toList(growable: false),
      updatedAtUtc: updatedAtUtc,
    );
  }

  final List<String> interests;
  final String? preferredTransportMode;
  final String? travelPace;
  final String? riskTolerance;
  final List<String> foodPreferences;
  final DateTime? updatedAtUtc;
}
