final class InterestOptionDto {
  const InterestOptionDto({required this.key, required this.source});

  factory InterestOptionDto.fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    final source = json['source'];
    if (key is! String || source is! String) {
      throw const FormatException('Invalid interest option.');
    }
    return InterestOptionDto(key: key, source: source);
  }

  final String key;
  final String source;
}

/// `GET /api/v1/traveler/preferences/options` response (UC-09). Returned
/// directly by the controller with no `{ success, data }` envelope.
final class TravelPreferenceOptionsDto {
  const TravelPreferenceOptionsDto({
    required this.interests,
    required this.preferredTransportModes,
    required this.travelPaces,
    required this.foodPreferences,
    required this.riskTolerances,
  });

  factory TravelPreferenceOptionsDto.fromJson(Map<String, dynamic> json) {
    final interests = json['interests'];
    if (interests is! List) {
      throw const FormatException('Invalid preference options response.');
    }

    return TravelPreferenceOptionsDto(
      interests: interests
          .map(
            (item) => InterestOptionDto.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      preferredTransportModes: _stringList(json['preferredTransportModes']),
      travelPaces: _stringList(json['travelPaces']),
      foodPreferences: _stringList(json['foodPreferences']),
      riskTolerances: _stringList(json['riskTolerances']),
    );
  }

  final List<InterestOptionDto> interests;
  final List<String> preferredTransportModes;
  final List<String> travelPaces;
  final List<String> foodPreferences;
  final List<String> riskTolerances;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    throw const FormatException('Invalid preference options response.');
  }
  return value.map((item) => item as String).toList(growable: false);
}
