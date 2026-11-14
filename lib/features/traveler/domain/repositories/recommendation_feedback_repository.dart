/// Explicit traveler feedback on a place, used by later recommendations.
abstract interface class RecommendationFeedbackRepository {
  /// A thumbs up ([liked]) or down for a stop of the traveler's own
  /// [itineraryId]. Sending the same [clientEventId] again is not counted
  /// twice. Throws a `Failure` when the answer could not be saved.
  Future<void> sendStopFeedback({
    required String clientEventId,
    required int itineraryId,
    required int poiId,
    required bool liked,
  });
}
