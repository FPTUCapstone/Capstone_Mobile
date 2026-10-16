import 'package:trip_mate_mobile/features/traveler/data/models/travel_preference_options_dto.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/travel_preferences_dto.dart';
import 'package:trip_mate_mobile/features/traveler/data/models/update_travel_preferences_request.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_preference_options.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_preferences.dart';

extension InterestOptionMapper on InterestOptionDto {
  InterestOption toDomain() => InterestOption(key: key, source: source);
}

extension TravelPreferenceOptionsMapper on TravelPreferenceOptionsDto {
  TravelPreferenceOptions toDomain() => TravelPreferenceOptions(
    interests: interests.map((item) => item.toDomain()).toList(growable: false),
    preferredTransportModes: preferredTransportModes,
    travelPaces: travelPaces,
    foodPreferences: foodPreferences,
    riskTolerances: riskTolerances,
  );
}

extension TravelPreferencesMapper on TravelPreferencesDto {
  TravelPreferences toDomain() => TravelPreferences(
    interests: interests,
    preferredTransportMode: preferredTransportMode,
    travelPace: travelPace,
    riskTolerance: riskTolerance,
    foodPreferences: foodPreferences,
    updatedAtUtc: updatedAtUtc,
  );
}

extension TravelPreferencesRequestMapper on TravelPreferences {
  UpdateTravelPreferencesRequest toRequest() => UpdateTravelPreferencesRequest(
    interests: interests,
    preferredTransportMode: preferredTransportMode,
    travelPace: travelPace,
    riskTolerance: riskTolerance,
    foodPreferences: foodPreferences,
  );
}
