import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_preference_options.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/travel_preferences.dart';

abstract interface class TravelPreferencesRepository {
  Future<TravelPreferenceOptions> getOptions();

  Future<TravelPreferences> getPreferences();

  /// Sends the full five-field state (UC-09 spec §4); the Backend is
  /// authoritative and the returned [TravelPreferences] is the new source of
  /// truth, not the caller's pre-submission values.
  Future<TravelPreferences> updatePreferences(TravelPreferences preferences);
}
