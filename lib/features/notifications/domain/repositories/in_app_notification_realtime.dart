/// Real-time hint stream for in-app notifications (`/hubs/notifications`).
/// Hints only prompt an authorized HTTP refetch; payloads are never treated as business truth.
abstract interface class InAppNotificationRealtime {
  Stream<void> get changes;

  Future<void> start();

  Future<void> stop();

  Future<void> dispose();
}
