import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_preference_options_dto.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_preferences_dto.dart';

void main() {
  group('TravelPreferencesDto.fromJson', () {
    test('accepts the complete API response with null optional values', () {
      final dto = TravelPreferencesDto.fromJson(_preferencesJson());

      expect(dto.interests, ['Beach']);
      expect(dto.preferredTransportMode, isNull);
      expect(dto.updatedAtUtc, DateTime.parse('2026-10-16T01:02:03Z'));
    });

    test('rejects a missing required response field', () {
      final json = _preferencesJson()..remove('travelPace');

      expect(
        () => TravelPreferencesDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an invalid updatedAtUtc instead of treating it as null', () {
      final json = _preferencesJson()..['updatedAtUtc'] = 'not-a-date';

      expect(
        () => TravelPreferencesDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-string and blank list values', () {
      final json = _preferencesJson()..['interests'] = ['Beach', 42];

      expect(
        () => TravelPreferencesDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('TravelPreferenceOptionsDto.fromJson', () {
    test('rejects an unknown interest source', () {
      final json = _optionsJson()
        ..['interests'] = [
          {'key': 'Beach', 'source': 'Unknown'},
        ];

      expect(
        () => TravelPreferenceOptionsDto.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects blank option keys and non-string option values', () {
      final blankKey = _optionsJson()
        ..['interests'] = [
          {'key': ' ', 'source': 'Category'},
        ];
      final nonStringValue = _optionsJson()..['travelPaces'] = ['Relaxed', 1];

      expect(
        () => TravelPreferenceOptionsDto.fromJson(blankKey),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TravelPreferenceOptionsDto.fromJson(nonStringValue),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

Map<String, dynamic> _preferencesJson() => {
  'interests': ['Beach'],
  'preferredTransportMode': null,
  'travelPace': 'Relaxed',
  'riskTolerance': 'Low',
  'foodPreferences': ['Vegetarian'],
  'updatedAtUtc': '2026-10-16T01:02:03Z',
};

Map<String, dynamic> _optionsJson() => {
  'interests': [
    {'key': 'Beach', 'source': 'Category'},
  ],
  'preferredTransportModes': ['Car'],
  'travelPaces': ['Relaxed'],
  'foodPreferences': ['NoRestriction'],
  'riskTolerances': ['Low'],
};
