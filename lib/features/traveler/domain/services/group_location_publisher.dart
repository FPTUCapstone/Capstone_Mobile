abstract interface class GroupLocationPublisher {
  Future<void> restoreActiveGroups();
  Future<bool> ensurePermission({bool request = false});
  Future<void> start(int groupId);
  Future<void> stop(int groupId);
  Future<void> suspend();
  Future<void> pauseForPermission();
  Future<void> resume();
  Future<void> stopAll();
  Future<bool> openSettings();
}
