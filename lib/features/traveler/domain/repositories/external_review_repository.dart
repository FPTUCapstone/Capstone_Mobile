import 'package:trip_mate_mobile/features/traveler/domain/entities/external_reviews.dart';

/// Tripadvisor rating and reviews of a place, read through the TripMate
/// backend (the Tripadvisor key never leaves it).
abstract interface class ExternalReviewRepository {
  Future<PoiExternalReviews> getReviews(int poiId, {int size = 5});

  /// Machine translation of one review into Vietnamese.
  Future<TranslatedReview> translate({
    required int poiId,
    required int reviewId,
  });
}
