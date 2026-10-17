import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_suggestion.dart';

abstract interface class ItinerarySuggestionRepository {
  /// Up to five places for [kind]: restaurants to add after the item
  /// [itemId] (`food`), or replacements for the item [itemId] (`replace`).
  Future<ItinerarySuggestions> getSuggestions({
    required int itineraryId,
    required SuggestionKind kind,
    required int itemId,
  });
}
