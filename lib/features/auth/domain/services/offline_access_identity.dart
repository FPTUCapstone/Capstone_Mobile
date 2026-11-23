/// Local read capability, distinct from server authentication. Implementations
/// retain only an account identifier and session generation in secure storage.
abstract interface class OfflineAccessIdentity {
  Future<int?> currentOwnerId();
  Future<int?> currentOnlineOwnerId();
  Future<String?> currentSessionKey();

  /// The auth coordinator already holds its session storage lock.
  Future<int?> ownerWhileSessionLocked();
  Future<void> enableForSession({
    required int userId,
    required String accessToken,
    required bool isTraveler,
  });
  Future<bool> disableForLogout();
  bool tokenHasExpired(String? accessToken);
  int? tokenOwnerId(String? accessToken);
}
