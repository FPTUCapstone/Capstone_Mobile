/// Tiny observable hub that lets the network layer invalidate the authenticated
/// session without depending on presentation classes. Only authenticated
/// (Bearer-carrying) requests that receive a 401 register interest here; auth
/// endpoint failures before a session exists never call [invalidate].
final class SessionCoordinator {
  final _handlers = <Future<void> Function()>{};

  void register(Future<void> Function() handler) => _handlers.add(handler);

  void unregister(Future<void> Function() handler) => _handlers.remove(handler);

  Future<void> invalidate() async {
    for (final handler in List.of(_handlers)) {
      await handler();
    }
  }
}
