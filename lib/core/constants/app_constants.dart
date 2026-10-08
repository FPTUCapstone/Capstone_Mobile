abstract final class AppConstants {
  static const appName = 'TripMate';
  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const sessionRoleKey = 'session_role';

  /// Backend-issued `userId` of the account that owns the persisted tokens.
  static const sessionUserIdKey = 'session_user_id';

  /// Single JSON record `{userId, role, applicationStatus, fullName, email}`.
  /// It is written as one value so the owner `userId` and the account data it
  /// protects can never be updated independently.
  static const sessionOwnerSnapshotKey = 'session_owner_snapshot';

  /// Legacy, unbound keys from builds before the owner snapshot existed. They
  /// are never read; they are only deleted during cleanup.
  static const sessionApplicationStatusKey = 'session_application_status';
  static const sessionFullNameKey = 'session_full_name';
  static const sessionEmailKey = 'session_email';
  static const keepSignedInKey = 'keep_signed_in';
}
