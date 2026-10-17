import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';

/// UC-13 navigation session contract. Failures are thrown as `Failure`
/// subclasses; Backend navigation error codes surface as `NavigationFailure`.
abstract interface class NavigationSessionRepository {
  Future<NavigationSession> start({
    required int itineraryId,
    required String idempotencyKey,
  });

  Future<NavigationSession> getById(int sessionId);

  Future<NavigationSession> reachItem({
    required int sessionId,
    required int itemId,
    required DateTime occurredAt,
  });

  Future<NavigationSession> skipItem({
    required int sessionId,
    required int itemId,
    required DateTime occurredAt,
  });

  /// Leaves the Exploring phase (state `Navigating`).
  Future<NavigationSession> depart({
    required int sessionId,
    required DateTime occurredAt,
  });

  Future<NavigationSession> complete(int sessionId);
}
