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
    const requiredKeys = [
      'interests',
      'preferredTransportMode',
      'travelPace',
      'riskTolerance',
      'foodPreferences',
      'updatedAtUtc',
    ];
    if (requiredKeys.any((key) => !json.containsKey(key))) {
      throw const FormatException('Invalid travel preferences response.');
    }

    final updatedAtUtc = _nullableDateTime(json['updatedAtUtc']);

    return TravelPreferencesDto(
      interests: _stringList(json['interests']),
      preferredTransportMode: _nullableString(json['preferredTransportMode']),
      travelPace: _nullableString(json['travelPace']),
      riskTolerance: _nullableString(json['riskTolerance']),
      foodPreferences: _stringList(json['foodPreferences']),
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

String? _nullableString(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid travel preferences response.');
  }
  return value;
}

DateTime? _nullableDateTime(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Invalid travel preferences response.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const FormatException('Invalid travel preferences response.');
  }
  return parsed;
}

List<String> _stringList(Object? value) {
  if (value is! List ||
      value.any((item) => item is! String || item.trim().isEmpty)) {
    throw const FormatException('Invalid travel preferences response.');
  }
  return value.cast<String>().toList(growable: false);
}
