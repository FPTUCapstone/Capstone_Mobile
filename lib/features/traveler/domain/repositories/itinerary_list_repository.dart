import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_summary.dart';

abstract interface class ItineraryListRepository {
  /// Lists the itineraries the signed-in Traveler can open, newest trip first.
  Future<ItinerarySummaryPage> listMine({int page = 1, int pageSize = 20});
}
