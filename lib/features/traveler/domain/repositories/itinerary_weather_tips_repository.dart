import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_weather_tips.dart';

abstract interface class ItineraryWeatherTipsRepository {
  /// UC-10: what to bring because of that day's weather, as the backend worked
  /// it out. `null` means "not available" (too far ahead, service off, any
  /// failure): callers hide the card and never guess. Never throws.
  Future<ItineraryWeatherTips?> getWeatherTips(int itineraryId);
}
