import 'package:equatable/equatable.dart';

/// UC-10: a create that answered `explanationPending: true`. The backend wrote
/// template sentences and is still writing the AI sentences in the background;
/// the detail page loads the itinerary again until they arrive.
///
/// It travels with the navigation from the create page to the detail page and
/// is never stored: the backend keeps no pending flag, and after a restart or
/// a later visit the stored sentences are already the AI's.
final class PendingExplanation extends Equatable {
  const PendingExplanation({
    required this.itineraryId,
    required this.createdAt,
    required this.template,
  });

  final int itineraryId;

  /// When the create response arrived; the refresh schedule counts from here.
  final DateTime createdAt;

  /// The trimmed template sentence per `sequenceNo` ('' when there was none).
  final Map<int, String> template;

  /// The route `extra` of the detail page, when it is a pending explanation
  /// of exactly [itineraryId]; anything else is ignored.
  static PendingExplanation? forRoute(Object? extra, int itineraryId) =>
      extra is PendingExplanation && extra.itineraryId == itineraryId
      ? extra
      : null;

  @override
  List<Object?> get props => [itineraryId, createdAt, template];
}
