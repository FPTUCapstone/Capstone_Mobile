import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/tour_operator_application_status.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/auth_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

enum _MobileRoleSupport { supported, administratorUnsupported, unknown }

/// The restore gate could not be proven closed before a new session was
/// persisted, so persisting would risk a restorable mixed-account session.
final class _SessionPersistenceException implements Exception {
  const _SessionPersistenceException();
}

/// Account data restored only when it is proven to belong to the persisted
/// session owner.
typedef _OwnedSnapshot = ({
  TourOperatorApplicationStatus applicationStatus,
  String? fullName,
  String? email,
});

/// Every persisted session key, restore gate first so a partial cleanup always
/// removes restorability before anything else.
const _sessionKeys = [
  AppConstants.keepSignedInKey,
  AppConstants.accessTokenKey,
  AppConstants.refreshTokenKey,
  AppConstants.sessionRoleKey,
  AppConstants.sessionUserIdKey,
  AppConstants.sessionOwnerSnapshotKey,
  AppConstants.sessionApplicationStatusKey,
  AppConstants.sessionFullNameKey,
  AppConstants.sessionEmailKey,
];

/// Owner data that must never outlive a session switch: the bound snapshot,
/// its owner id and the legacy unbound keys.
const _ownerDataKeys = [
  AppConstants.sessionOwnerSnapshotKey,
  AppConstants.sessionUserIdKey,
  AppConstants.sessionApplicationStatusKey,
  AppConstants.sessionFullNameKey,
  AppConstants.sessionEmailKey,
];

final class AuthSessionCubit extends Cubit<AuthSessionState> {
  AuthSessionCubit([
    this._authRepository,
    this._secureStorage,
    this._firebaseAuthService,
  ]) : super(const AuthSessionState.unauthenticated());

  final AuthRepository? _authRepository;
  final SecureStorageService? _secureStorage;
  final AuthIdentityService? _firebaseAuthService;
  bool _verificationActionInProgress = false;

  Future<String?> get currentFirebaseUserEmail async =>
      _firebaseAuthService?.currentUserEmail;

  /// UC-05 backend-integrated sign-out. The session deliberately stays
  /// `authenticated` while the remote request is in flight so the router guard
  /// never redirects early. A remote failure is recorded but never prevents
  /// the M7 local invalidation pipeline from running.
  Future<void> signOut() async {
    if (!state.isAuthenticated) return;
    // The state's own operation marker is the duplicate guard: it is set
    // synchronously, before the first await, so a second intent cannot start.
    if (state.operation == AuthSessionOperation.signOut) return;

    final role = state.role!;
    final applicationStatus = state.applicationStatus;
    final fullName = state.fullName;
    final email = state.email;
    emit(
      AuthSessionState.authenticated(
        role,
        applicationStatus: applicationStatus,
        operation: AuthSessionOperation.signOut,
        fullName: fullName,
        email: email,
      ),
    );

    final storage = _secureStorage;
    final repository = _authRepository;
    final refreshToken = storage == null
        ? null
        : await _readRefreshTokenQuietly(storage);

    var remoteFailed = repository == null;
    if (repository != null) {
      try {
        await repository.logout(refreshToken);
      } on NetworkException {
        remoteFailed = true;
      } on ServerException {
        remoteFailed = true;
      } catch (_) {
        // Unexpected non-remote error: keep the fail-safe (never leave the
        // in-flight marker set) and let it surface.
        if (state.isAuthenticated) {
          emit(
            AuthSessionState.authenticated(
              role,
              applicationStatus: applicationStatus,
              fullName: fullName,
              email: email,
            ),
          );
        }
        rethrow;
      }
    }

    final localComplete = await _invalidateLocalSessionForSignOut();

    if (!localComplete) {
      // Fail closed: the persisted session could still satisfy the restore
      // predicate, so no local sign-out may be claimed. The M3 copy would be
      // false in this state, so only the local-cleanup copy is emitted and the
      // user may retry; no storage or remote detail is exposed.
      emit(
        AuthSessionState.authenticated(
          role,
          applicationStatus: applicationStatus,
          errorMessage: signOutLocalCleanupFailureMessage,
          fullName: fullName,
          email: email,
        ),
      );
      return;
    }

    // Provider sign-out is best effort and runs only once the persisted session
    // is proven non-restorable; a provider failure must not change that.
    await _bestEffortProviderSignOut();

    emit(
      AuthSessionState.unauthenticated(
        errorMessage: remoteFailed ? signOutRemoteFailureMessage : null,
      ),
    );
  }

  /// Reads the stored refresh token for sign-out. A missing, blank or
  /// unreadable value is reported as "no credential", so a storage problem can
  /// never block the user's sign-out or leak a storage error to the UI.
  Future<String?> _readRefreshTokenQuietly(SecureStorageService storage) async {
    try {
      final token = await storage.read(AppConstants.refreshTokenKey);
      if (token == null || token.trim().isEmpty) return null;
      return token;
    } catch (_) {
      return null;
    }
  }

  /// M7: makes the persisted session non-restorable for sign-out, bounded to at
  /// most two attempts. Returns true only when the ACTUAL restore predicate is
  /// proven false; anything unproven fails closed.
  Future<bool> _invalidateLocalSessionForSignOut() async {
    final storage = _secureStorage;
    if (storage == null) return false;

    for (var attempt = 0; attempt < 2; attempt++) {
      await _attemptLocalInvalidation(storage);
      final restorable = await _isPersistedSessionRestorable(storage);
      if (restorable == false) return true;
    }
    return false;
  }

  /// One invalidation attempt: invalidate the restore gate first, then clean
  /// every session key independently — a failing key must never stop the
  /// remaining best-effort deletions.
  Future<void> _attemptLocalInvalidation(SecureStorageService storage) async {
    await _invalidateRestoreGate(storage);
    for (final key in [..._sessionKeys.skip(1), AppConstants.keepSignedInKey]) {
      try {
        await storage.delete(key);
      } catch (_) {
        // Continue with the remaining keys; verification decides fail-closed.
      }
    }
  }

  /// Makes `keep_signed_in == 'true'` unsatisfiable using the existing storage
  /// API and the existing representation: delete the key, or persist 'false'
  /// when the delete did not take effect. No tombstone key is introduced.
  Future<void> _invalidateRestoreGate(SecureStorageService storage) async {
    try {
      await storage.delete(AppConstants.keepSignedInKey);
      return;
    } catch (_) {
      // Fall through to the explicit 'false' representation.
    }
    try {
      await storage.write(AppConstants.keepSignedInKey, 'false');
    } catch (_) {
      // Unproven; the verification step decides fail-closed.
    }
  }

  /// Evaluates the exact predicate `restoreSession()` uses, from persisted
  /// state. Returns null when the state cannot be read — unproven, so the
  /// caller must fail closed.
  Future<bool?> _isPersistedSessionRestorable(
    SecureStorageService storage,
  ) async {
    try {
      final keepSignedIn = await storage.read(AppConstants.keepSignedInKey);
      final accessToken = await storage.read(AppConstants.accessTokenKey);
      final refreshToken = await storage.read(AppConstants.refreshTokenKey);
      final role = _restorableRole(
        keepSignedIn: keepSignedIn,
        accessToken: accessToken,
        refreshToken: refreshToken,
        storedRole: await storage.read(AppConstants.sessionRoleKey),
      );
      return role != null;
    } catch (_) {
      return null;
    }
  }

  /// Single source of truth for the persisted restore predicate. Returning a
  /// role means the session is restorable; null means it is not.
  UserRole? _restorableRole({
    required String? keepSignedIn,
    required String? accessToken,
    required String? refreshToken,
    required String? storedRole,
  }) {
    if (keepSignedIn != 'true' ||
        accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }
    return switch (storedRole) {
      'traveler' => UserRole.traveler,
      'tourOperator' => UserRole.tourOperator,
      _ => null,
    };
  }

  Future<void> restoreSession() async {
    final storage = _secureStorage;
    if (storage == null) return;

    final keepSignedIn = await storage.read(AppConstants.keepSignedInKey);
    final accessToken = await storage.read(AppConstants.accessTokenKey);
    final refreshToken = await storage.read(AppConstants.refreshTokenKey);
    final storedRole = await storage.read(AppConstants.sessionRoleKey);
    final role = _restorableRole(
      keepSignedIn: keepSignedIn,
      accessToken: accessToken,
      refreshToken: refreshToken,
      storedRole: storedRole,
    );

    if (role != null) {
      // Provisional restore: replays the backend-issued account data persisted
      // at sign-in. This is not proof the access token is still server-valid; a
      // later 401 clears it. Account data (identity and Tour Operator
      // application status) is restored only from the owner snapshot bound to
      // the persisted session owner; anything unproven stays absent.
      final owned = await _readOwnedSnapshot(storage, role);
      emit(
        AuthSessionState.authenticated(
          role,
          applicationStatus:
              owned?.applicationStatus ??
              TourOperatorApplicationStatus.unresolved,
          fullName: owned?.fullName,
          email: owned?.email,
        ),
      );
      await _deleteLegacyOwnerKeysBestEffort(storage);
      return;
    }

    await _clearStoredSessionBestEffort(storage);
  }

  /// Returns the persisted account data only when its embedded `userId` equals
  /// the persisted session owner and its role equals the restored role. A
  /// missing, unreadable, malformed or foreign snapshot yields null, so a
  /// previous account's data can never be attached to the current session.
  Future<_OwnedSnapshot?> _readOwnedSnapshot(
    SecureStorageService storage,
    UserRole role,
  ) async {
    try {
      final ownerId = int.tryParse(
        (await storage.read(AppConstants.sessionUserIdKey))?.trim() ?? '',
      );
      final raw = await storage.read(AppConstants.sessionOwnerSnapshotKey);
      if (ownerId == null || raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final snapshotUserId = decoded['userId'];
      if (snapshotUserId is! int || snapshotUserId != ownerId) return null;
      if (decoded['role'] != role.name) return null;
      final applicationStatus = decoded['applicationStatus'];
      final fullName = decoded['fullName'];
      final email = decoded['email'];
      return (
        applicationStatus: _applicationStatusFromStorage(
          applicationStatus is String ? applicationStatus : null,
        ),
        fullName: _cleanIdentity(fullName is String ? fullName : null),
        email: _cleanIdentity(email is String ? email : null),
      );
    } catch (_) {
      return null;
    }
  }

  /// Legacy unbound account keys are never trusted; remove them so their PII
  /// does not linger on the device.
  Future<void> _deleteLegacyOwnerKeysBestEffort(
    SecureStorageService storage,
  ) async {
    for (final key in [
      AppConstants.sessionApplicationStatusKey,
      AppConstants.sessionFullNameKey,
      AppConstants.sessionEmailKey,
    ]) {
      try {
        await storage.delete(key);
      } catch (_) {
        // Never read again, so a failed delete cannot expose the value.
      }
    }
  }

  /// Session-expiry hook for the network layer: an authenticated (non-auth-
  /// endpoint) 401 clears the complete local session and returns to sign-in.
  Future<void> handleSessionExpired() async {
    emit(const AuthSessionState.unauthenticated());
    final storage = _secureStorage;
    if (storage != null) {
      await _clearStoredSessionBestEffort(storage);
    }
    // Firebase sign-out is best-effort here. A provider failure must never
    // keep a server-rejected Mobile session visible after its local identity
    // and credentials have been cleared.
    try {
      await _firebaseAuthService?.signOut();
    } catch (_) {
      // Local invalidation is already complete.
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
    bool keepSignedIn = true,
  }) async {
    emit(const AuthSessionState.loading());
    final repository = _authRepository;
    final storage = _secureStorage;
    if (repository == null || storage == null) {
      emit(const AuthSessionState.failure('Sign in is unavailable.'));
      return;
    }
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final credentials = AuthCredentials(
        email: normalizedEmail,
        password: password,
      );
      // TripMate Backend is the sole password authority. The password is sent
      // directly to POST /api/v1/auth/login; BE verifies dbo.Users.password_hash
      // via IPasswordHasherService.Verify. Firebase password authentication is
      // not used for normal email/password sign-in.
      final response = await repository.login(credentials, null);
      await _establishSession(storage, response, keepSignedIn: keepSignedIn);
    } on ServerException catch (error) {
      if (error.statusCode == 403 &&
          error.code == 'auth.admin_mobile_sign_in_disabled') {
        await _clearStoredSessionBestEffort(storage);
        emit(const AuthSessionState.failure(administratorWebOnlyMessage));
        await _bestEffortProviderSignOut();
        return;
      }
      emit(AuthSessionState.failure(error.message));
    } on AppException catch (error) {
      emit(AuthSessionState.failure(error.message));
    } catch (_) {
      emit(
        const AuthSessionState.failure(
          'Unable to sign in. Please try again later.',
        ),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    final repository = _authRepository;
    final storage = _secureStorage;
    final firebaseAuth = _firebaseAuthService;
    if (repository == null || storage == null || firebaseAuth == null) {
      emit(const AuthSessionState.failure('Google sign-in is unavailable.'));
      return;
    }

    emit(const AuthSessionState.loading());
    try {
      final firebaseIdToken = await firebaseAuth.signInWithGoogle();
      final response = await repository.googleAuth(firebaseIdToken);
      await _establishSession(storage, response);
    } on AuthIdentityException catch (error) {
      emit(
        error.failure == AuthIdentityFailure.canceled
            ? const AuthSessionState.unauthenticated()
            : const AuthSessionState.failure(
                'Google sign-in failed. Please try again.',
              ),
      );
    } on AppException catch (error) {
      if (error is ServerException &&
          error.code == 'auth.admin_google_sign_in_disabled') {
        await _clearStoredSessionBestEffort(storage);
        emit(const AuthSessionState.failure(administratorWebOnlyMessage));
        await _bestEffortProviderSignOut();
        return;
      }
      emit(AuthSessionState.failure(error.message));
    } catch (_) {
      emit(
        const AuthSessionState.failure(
          'Google sign-in failed. Please try again.',
        ),
      );
    }
  }

  Future<void> resendVerificationEmail() async {
    if (_verificationActionInProgress) return;
    final firebaseAuth = _firebaseAuthService;
    if (firebaseAuth == null) {
      emit(
        const AuthSessionState.failure('Email verification is unavailable.'),
      );
      return;
    }

    _verificationActionInProgress = true;
    emit(
      const AuthSessionState.loading(
        operation: AuthSessionOperation.resendVerificationEmail,
      ),
    );
    try {
      await firebaseAuth.sendEmailVerification();
      emit(
        const AuthSessionState.verificationEmailSent(
          'A fresh verification link has been sent to your email address.',
        ),
      );
    } on AuthIdentityException catch (error) {
      emit(
        AuthSessionState.failure(
          _identityVerificationMessage(error.failure, isResend: true),
          startResendCooldown:
              error.failure == AuthIdentityFailure.tooManyRequests,
        ),
      );
    } catch (_) {
      emit(
        const AuthSessionState.failure(
          'Unable to send verification email. Please try again later or sign in.',
        ),
      );
    } finally {
      _verificationActionInProgress = false;
    }
  }

  Future<void> verifyEmail() async {
    if (_verificationActionInProgress) return;
    final repository = _authRepository;
    final storage = _secureStorage;
    final firebaseAuth = _firebaseAuthService;
    if (repository == null || storage == null || firebaseAuth == null) {
      emit(
        const AuthSessionState.failure('Email verification is unavailable.'),
      );
      return;
    }

    _verificationActionInProgress = true;
    emit(
      const AuthSessionState.loading(
        operation: AuthSessionOperation.verifyEmail,
      ),
    );
    try {
      final firebaseIdToken = await firebaseAuth.refreshIdToken();
      if (firebaseIdToken == null) {
        emit(
          const AuthSessionState.failure(
            'Please verify your email before continuing.',
          ),
        );
        return;
      }
      final response = await repository.verifyEmail(firebaseIdToken);
      await _establishSession(storage, response);
    } on AuthIdentityException catch (error) {
      emit(
        AuthSessionState.failure(
          _identityVerificationMessage(error.failure, isResend: false),
        ),
      );
    } on AppException catch (error) {
      emit(AuthSessionState.failure(error.message));
    } catch (_) {
      emit(
        const AuthSessionState.failure(
          'Email verification could not be completed. Please try again.',
        ),
      );
    } finally {
      _verificationActionInProgress = false;
    }
  }

  /// Establishes a session from a backend-issued response. The authoritative
  /// role is classified before any write: Administrator fails closed with the
  /// Web-only message (nothing persisted), an unknown/missing role never
  /// fabricates Traveler, and only supported roles persist + authenticate.
  Future<bool> _establishSession(
    SecureStorageService storage,
    AuthSession response, {
    bool keepSignedIn = true,
  }) async {
    switch (_classifyRole(response.role)) {
      case _MobileRoleSupport.administratorUnsupported:
        await _clearStoredSessionBestEffort(storage);
        emit(const AuthSessionState.failure(administratorWebOnlyMessage));
        await _bestEffortProviderSignOut();
        return false;
      case _MobileRoleSupport.unknown:
        emit(
          const AuthSessionState.failure(
            'Unable to sign in. Please try again later.',
          ),
        );
        return false;
      case _MobileRoleSupport.supported:
        final role = response.role == 'TourOperator'
            ? UserRole.tourOperator
            : UserRole.traveler;
        try {
          await _saveSession(
            storage,
            response,
            role: role,
            keepSignedIn: keepSignedIn,
          );
        } catch (_) {
          // Persistence failed before the session could be committed. Remove
          // whatever was partially written; the caller reports a generic
          // failure and no authenticated state is emitted.
          await _clearStoredSessionBestEffort(storage);
          rethrow;
        }
        emit(
          AuthSessionState.authenticated(
            role,
            applicationStatus: response.applicationStatus,
            fullName: _cleanIdentity(response.fullName),
            email: _cleanIdentity(response.email),
          ),
        );
        return true;
    }
  }

  _MobileRoleSupport _classifyRole(String? raw) => switch (raw) {
    'Traveler' || 'TourOperator' => _MobileRoleSupport.supported,
    'Administrator' => _MobileRoleSupport.administratorUnsupported,
    _ => _MobileRoleSupport.unknown,
  };

  static const administratorWebOnlyMessage =
      'Administrator accounts are supported on Web only.';

  static const signOutRemoteFailureMessage =
      'You\'re signed out on this device, but we couldn\'t complete '
      'server-side sign-out.';

  /// Approved local-cleanup-failure copy — shown only when the persisted
  /// session could not be proven non-restorable, so no local sign-out may be
  /// claimed.
  static const signOutLocalCleanupFailureMessage =
      'We couldn\'t complete sign out on this device. Please try again.';

  Future<void> _bestEffortProviderSignOut() async {
    try {
      await _firebaseAuthService?.signOut();
    } catch (_) {
      // Provider cleanup cannot override the locally settled refusal.
    }
  }

  Future<void> _saveSession(
    SecureStorageService storage,
    AuthSession response, {
    required UserRole role,
    bool keepSignedIn = true,
  }) async {
    // 1. Close the restore gate and prove it closed before anything else is
    //    replaced, so no interleaving of old and new keys is ever restorable.
    await _closeRestoreGate(storage);

    // 2. Drop the previous owner's account data. A failed delete is tolerated:
    //    restore only trusts a snapshot whose userId equals the new owner id,
    //    and a stale snapshot is overwritten below.
    for (final key in _ownerDataKeys) {
      try {
        await storage.delete(key);
      } catch (_) {
        // Ownership binding, not this delete, protects the next restore.
      }
    }

    // 3. Credentials and the Backend-issued owner id are required; any failure
    //    aborts the sign-in and the caller clears the partial write.
    await storage.write(AppConstants.accessTokenKey, response.accessToken);
    await storage.write(AppConstants.refreshTokenKey, response.refreshToken);
    await storage.write(AppConstants.sessionRoleKey, role.name);
    await storage.write(
      AppConstants.sessionUserIdKey,
      response.userId.toString(),
    );

    // 4. Account data is written as one owner-bound record and read back. If it
    //    cannot be committed and verified, the session stays usable in memory
    //    but is never made restorable.
    final applicationStatus = response.applicationStatus;
    final snapshot = jsonEncode({
      'userId': response.userId,
      'role': role.name,
      'applicationStatus':
          applicationStatus == TourOperatorApplicationStatus.unresolved
          ? null
          : applicationStatus.name,
      'fullName': _cleanIdentity(response.fullName),
      'email': _cleanIdentity(response.email),
    });
    var ownershipCommitted = false;
    try {
      await storage.write(AppConstants.sessionOwnerSnapshotKey, snapshot);
      ownershipCommitted = await _readOwnedSnapshot(storage, role) != null;
    } catch (_) {
      ownershipCommitted = false;
    }

    // 5. Open the gate last, and only for a fully committed session.
    if (keepSignedIn && ownershipCommitted) {
      await storage.write(AppConstants.keepSignedInKey, 'true');
    } else {
      try {
        await storage.write(AppConstants.keepSignedInKey, 'false');
      } catch (_) {
        // The gate is already proven closed by step 1.
      }
    }
  }

  /// Makes the restore gate unsatisfiable and verifies it from storage. Throws
  /// when that cannot be proven, so a new session is never written next to a
  /// previous session's still-open gate.
  Future<void> _closeRestoreGate(SecureStorageService storage) async {
    await _invalidateRestoreGate(storage);
    final String? gate;
    try {
      gate = await storage.read(AppConstants.keepSignedInKey);
    } catch (_) {
      throw const _SessionPersistenceException();
    }
    if (gate == 'true') throw const _SessionPersistenceException();
  }

  /// Backend-issued identity is trimmed; blank means absent. Never a fallback.
  static String? _cleanIdentity(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Clears every persisted session key. The restore gate is invalidated first
  /// (delete, or persist 'false'), so a key that fails to delete can never
  /// leave the discarded session restorable.
  Future<void> _clearStoredSessionBestEffort(
    SecureStorageService storage,
  ) async {
    await _invalidateRestoreGate(storage);
    for (final key in _sessionKeys) {
      try {
        await storage.delete(key);
      } catch (_) {
        // Continue clearing the remaining fields; in-memory state is already
        // unauthenticated and no storage error is exposed to the user.
      }
    }
  }

  // Role classification is handled by _establishSession/_classifyRole; there is
  // intentionally no fallback that maps an unknown role to Traveler.

  String _identityVerificationMessage(
    AuthIdentityFailure failure, {
    required bool isResend,
  }) => switch (failure) {
    AuthIdentityFailure.tooManyRequests =>
      'Too many resend attempts. Please wait a few minutes before trying again.',
    AuthIdentityFailure.noCurrentUser =>
      isResend
          ? 'Your verification session has expired. Please sign in to request a new verification link.'
          : 'Your verification session has expired. Please sign in and request a new verification link.',
    AuthIdentityFailure.network =>
      'TripMate is temporarily unable to process your request. Please check your connection and try again.',
    _ =>
      isResend
          ? 'Unable to send verification email. Please try again later or sign in.'
          : 'Email verification could not be completed. Please try again.',
  };

  TourOperatorApplicationStatus _applicationStatusFromStorage(String? value) =>
      switch (value) {
        'Approved' || 'approved' => TourOperatorApplicationStatus.approved,
        'PendingApproval' ||
        'pendingApproval' => TourOperatorApplicationStatus.pendingApproval,
        'Rejected' || 'rejected' => TourOperatorApplicationStatus.rejected,
        _ => TourOperatorApplicationStatus.unresolved,
      };
}
