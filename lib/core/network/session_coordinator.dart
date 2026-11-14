/// Tiny observable hub that lets the network layer invalidate the authenticated
/// session without depending on presentation classes. Only authenticated
/// (Bearer-carrying) requests that receive a 401 register interest here; auth
/// endpoint failures before a session exists never call [invalidate].
final class SessionCoordinator {
  final _handlers =
      <
        Future<void> Function(),
        Future<void> Function(Future<bool> Function())?
      >{};

  /// Async cleanup handlers use [guarded] to recheck session identity before
  /// changing credentials or authentication state after awaited work.
  void register(
    Future<void> Function() handler, {
    Future<void> Function(Future<bool> Function())? guarded,
  }) => _handlers[handler] = guarded;

  void unregister(Future<void> Function() handler) => _handlers.remove(handler);

  Future<void> invalidate({Future<bool> Function()? isCurrent}) async {
    for (final entry in List.of(_handlers.entries)) {
      if (isCurrent != null && !await isCurrent()) continue;
      final guarded = entry.value;
      if (isCurrent != null && guarded != null) {
        await guarded(isCurrent);
      } else {
        await entry.key();
      }
    }
  }
}
