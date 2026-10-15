import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/itinerary_generation.dart';
import 'package:trip_mate_mobile/features/traveler/domain/entities/navigation_session.dart';
import 'package:trip_mate_mobile/features/traveler/domain/repositories/navigation_session_repository.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/demo/active_trip_demo_fixtures.dart';

/// DEMO_ONLY: in-memory navigation session for debug previews without a
/// Backend. It mirrors the Backend UC-13 rules (flexible order, skip,
/// Exploring, completion reasons) and never performs network calls.
final class DemoNavigationSessionRepository
    implements NavigationSessionRepository {
  DemoNavigationSessionRepository({
    NavigationSession? initialSession,
    this.transportMode,
  }) : _session = initialSession;

  /// The planned mode carried by sessions this repository starts.
  final TransportMode? transportMode;
  NavigationSession? _session;

  @override
  Future<NavigationSession> start({
    required int itineraryId,
    required String idempotencyKey,
  }) async {
    return _session ??= ActiveTripDemoFixtures.createDemoSession(
      itineraryId: itineraryId,
      transportMode: transportMode,
    );
  }

  @override
  Future<NavigationSession> getById(int sessionId) async => _require();

  @override
  Future<NavigationSession> reachItem({
    required int sessionId,
    required int itemId,
    required DateTime occurredAt,
  }) async {
    final session = _require();
    final item = _item(session, itemId);
    if (item.isReached) return session;
    _ensureOpen(session);
    return _session = _rebuild(
      session,
      state: NavigationSessionState.exploring,
      exploringItemId: itemId,
      items: _replace(
        session,
        item.copyWith(
          status: NavigationItemStatus.reached,
          reachedAt: occurredAt,
        ),
      ),
    );
  }

  @override
  Future<NavigationSession> skipItem({
    required int sessionId,
    required int itemId,
    required DateTime occurredAt,
  }) async {
    final session = _require();
    final item = _item(session, itemId);
    if (item.status == NavigationItemStatus.skipped) return session;
    if (item.isReached) {
      throw const NavigationFailure(
        'This stop was already reached.',
        reason: NavigationFailureReason.itemAlreadyReached,
      );
    }
    _ensureOpen(session);
    return _session = _rebuild(
      session,
      items: _replace(
        session,
        item.copyWith(
          status: NavigationItemStatus.skipped,
          skippedAt: occurredAt,
        ),
      ),
    );
  }

  @override
  Future<NavigationSession> depart({
    required int sessionId,
    required DateTime occurredAt,
  }) async {
    final session = _require();
    _ensureOpen(session);
    return _session = _rebuild(
      session,
      state: NavigationSessionState.navigating,
      clearExploring: true,
    );
  }

  @override
  Future<NavigationSession> complete(int sessionId) async {
    final session = _require();
    if (session.isCompleted) return session;
    return _session = _rebuild(
      session,
      state: NavigationSessionState.completed,
      completionReason: session.hasPendingItems
          ? NavigationCompletionReason.travelerStopped
          : NavigationCompletionReason.routeFinished,
      endedAt: DateTime.now().toUtc(),
      clearExploring: true,
    );
  }

  NavigationSession _require() {
    final session = _session;
    if (session == null) {
      throw const NavigationFailure(
        'This navigation session no longer exists.',
        reason: NavigationFailureReason.sessionNotFound,
      );
    }
    return session;
  }

  static void _ensureOpen(NavigationSession session) {
    if (session.isCompleted) {
      throw const NavigationFailure(
        'This navigation session has already ended.',
        reason: NavigationFailureReason.sessionCompleted,
      );
    }
  }

  static NavigationSessionItem _item(NavigationSession session, int itemId) {
    final item = session.itemById(itemId);
    if (item == null) {
      throw const NavigationFailure(
        'This stop is not part of the navigation session.',
        reason: NavigationFailureReason.itemNotNavigable,
      );
    }
    return item;
  }

  static List<NavigationSessionItem> _replace(
    NavigationSession session,
    NavigationSessionItem updated,
  ) => [
    for (final item in session.items)
      item.itemId == updated.itemId ? updated : item,
  ];

  static NavigationSession _rebuild(
    NavigationSession session, {
    NavigationSessionState? state,
    NavigationCompletionReason? completionReason,
    DateTime? endedAt,
    int? exploringItemId,
    bool clearExploring = false,
    List<NavigationSessionItem>? items,
  }) {
    final nextItems = items ?? session.items;
    final pending = nextItems.where(
      (item) => item.status == NavigationItemStatus.pending,
    );
    return NavigationSession(
      sessionId: session.sessionId,
      itineraryId: session.itineraryId,
      itineraryVersion: session.itineraryVersion,
      state: state ?? session.state,
      completionReason: completionReason ?? session.completionReason,
      startedAt: session.startedAt,
      expiresAt: session.expiresAt,
      endedAt: endedAt ?? session.endedAt,
      exploringItemId: clearExploring
          ? null
          : (exploringItemId ?? session.exploringItemId),
      nextItemId: pending.isEmpty ? null : pending.first.itemId,
      items: nextItems,
      transportMode: session.transportMode,
    );
  }
}
