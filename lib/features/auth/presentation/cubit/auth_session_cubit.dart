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

  Future<void> clearSession() async {
    await _clearLocalSession();
    emit(const AuthSessionState.unauthenticated());
  }

  /// Local-only cleanup primitive: deletes the persisted session and ends the
  /// provider identity without choosing the terminal state, so sign-out can
  /// emit exactly one authoritative terminal state.
  Future<void> _clearLocalSession() async {
    final storage = _secureStorage;
    if (storage != null) {
      await _clearStoredSession(storage);
    }
    await _firebaseAuthService?.signOut();
  }

  /// UC-05 backend-integrated sign-out. The session deliberately stays
  /// `authenticated` while the remote request is in flight so the router guard
  /// never redirects early. Local cleanup starts only after backend success.
  Future<void> signOut() async {
    if (!state.isAuthenticated) return;
    // The state's own operation marker is the duplicate guard: it is set
    // synchronously, before the first await, so a second intent cannot start.
    if (state.operation == AuthSessionOperation.signOut) return;

    final role = state.role!;
    final applicationStatus = state.applicationStatus;
    emit(
      AuthSessionState.authenticated(
        role,
        applicationStatus: applicationStatus,
        operation: AuthSessionOperation.signOut,
      ),
    );

    final storage = _secureStorage;
    final repository = _authRepository;
    final refreshToken = storage == null
        ? null
        : await _readRefreshTokenQuietly(storage);

    if (repository == null) {
      emit(
        AuthSessionState.authenticated(
          role,
          applicationStatus: applicationStatus,
          errorMessage: signOutFailureMessage,
        ),
      );
      return;
    }

    try {
      await repository.logout(refreshToken);
    } on NetworkException {
      emit(
        AuthSessionState.authenticated(
          role,
          applicationStatus: applicationStatus,
          errorMessage: signOutFailureMessage,
        ),
      );
      return;
    } on ServerException {
      emit(
        AuthSessionState.authenticated(
          role,
          applicationStatus: applicationStatus,
          errorMessage: signOutFailureMessage,
        ),
      );
      return;
    } catch (_) {
      // Unexpected non-remote error: keep the pre-T04 fail-safe (never leave the
      // in-flight marker set) and let it surface.
      if (state.isAuthenticated) {
        emit(
          AuthSessionState.authenticated(
            role,
            applicationStatus: applicationStatus,
          ),
        );
      }
      rethrow;
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
        ),
      );
      return;
    }

    // Provider sign-out is best effort and runs only once the persisted session
    // is proven non-restorable; a provider failure must not change that.
    await _bestEffortProviderSignOut();

    emit(const AuthSessionState.unauthenticated());
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
    for (final key in [
      AppConstants.accessTokenKey,
      AppConstants.refreshTokenKey,
      AppConstants.sessionRoleKey,
      AppConstants.sessionApplicationStatusKey,
      AppConstants.keepSignedInKey,
    ]) {
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
      final role = _roleFromStorage(
        await storage.read(AppConstants.sessionRoleKey),
      );
      return keepSignedIn == 'true' &&
          accessToken != null &&
          accessToken.isNotEmpty &&
          refreshToken != null &&
          refreshToken.isNotEmpty &&
          role != null;
    } catch (_) {
      return null;
    }
  }

  /// Mirrors the role mapping inside `restoreSession()`; that method is
  /// intentionally left untouched.
  UserRole? _roleFromStorage(String? value) => switch (value) {
    'traveler' => UserRole.traveler,
    'tourOperator' => UserRole.tourOperator,
    _ => null,
  };

  Future<void> restoreSession() async {
    final storage = _secureStorage;
    if (storage == null) return;

    final keepSignedIn = await storage.read(AppConstants.keepSignedInKey);
    final accessToken = await storage.read(AppConstants.accessTokenKey);
    final refreshToken = await storage.read(AppConstants.refreshTokenKey);
    final storedRole = await storage.read(AppConstants.sessionRoleKey);
    final role = switch (storedRole) {
      'traveler' => UserRole.traveler,
      'tourOperator' => UserRole.tourOperator,
      _ => null,
    };

    if (keepSignedIn == 'true' &&
        accessToken != null &&
        accessToken.isNotEmpty &&
        refreshToken != null &&
        refreshToken.isNotEmpty &&
        role != null) {
      // Provisional restore: replays the backend-issued identity persisted at
      // sign-in. This is not proof the access token is still server-valid; a
      // later 401 clears it.
      final storedApplicationStatus = await storage.read(
        AppConstants.sessionApplicationStatusKey,
      );
      emit(
        AuthSessionState.authenticated(
          role,
          applicationStatus: _applicationStatusFromStorage(
            storedApplicationStatus,
          ),
        ),
      );
      return;
    }

    await _clearStoredSessionBestEffort(storage);
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
    final firebaseAuth = _firebaseAuthService;
    if (repository == null || storage == null || firebaseAuth == null) {
      emit(const AuthSessionState.failure('Sign in is unavailable.'));
      return;
    }
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final firebaseIdToken = await firebaseAuth.signInWithEmail(
        email: normalizedEmail,
        password: password,
      );
      final credentials = AuthCredentials(
        email: normalizedEmail,
        password: password,
      );
      final response = await _loginOrActivateVerifiedUser(
        repository,
        credentials,
        firebaseIdToken,
      );
      await _establishSession(storage, response, keepSignedIn: keepSignedIn);
    } on AuthIdentityException catch (error) {
      emit(AuthSessionState.failure(_identitySignInMessage(error.failure)));
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
        await _clearStoredSession(storage);
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
        await _clearStoredSession(storage);
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
        await _saveSession(
          storage,
          response,
          role: role,
          keepSignedIn: keepSignedIn,
        );
        emit(
          AuthSessionState.authenticated(
            role,
            applicationStatus: response.applicationStatus,
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

  static const signOutFailureMessage =
      'We couldn\'t complete sign out. Please try again.';

  // Compatibility alias for existing views/tests while the retry copy remains
  // centralized in [signOutFailureMessage].
  static const signOutRemoteFailureMessage = signOutFailureMessage;

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
    await storage.write(AppConstants.accessTokenKey, response.accessToken);
    await storage.write(AppConstants.refreshTokenKey, response.refreshToken);
    await storage.write(AppConstants.sessionRoleKey, role.name);
    // Persist application status only when the backend issued one, so a
    // Traveler session keeps the same stored shape as before.
    final applicationStatus = response.applicationStatus;
    if (applicationStatus != TourOperatorApplicationStatus.unresolved) {
      await storage.write(
        AppConstants.sessionApplicationStatusKey,
        applicationStatus.name,
      );
    } else {
      await storage.delete(AppConstants.sessionApplicationStatusKey);
    }
    await storage.write(AppConstants.keepSignedInKey, keepSignedIn.toString());
  }

  Future<void> _clearStoredSession(SecureStorageService storage) async {
    await storage.delete(AppConstants.accessTokenKey);
    await storage.delete(AppConstants.refreshTokenKey);
    await storage.delete(AppConstants.sessionRoleKey);
    await storage.delete(AppConstants.sessionApplicationStatusKey);
    await storage.delete(AppConstants.keepSignedInKey);
  }

  Future<void> _clearStoredSessionBestEffort(
    SecureStorageService storage,
  ) async {
    for (final key in [
      AppConstants.keepSignedInKey,
      AppConstants.sessionRoleKey,
      AppConstants.accessTokenKey,
      AppConstants.refreshTokenKey,
      AppConstants.sessionApplicationStatusKey,
    ]) {
      try {
        await storage.delete(key);
      } catch (_) {
        // Continue clearing the remaining fields; in-memory state is already
        // unauthenticated and no storage error is exposed to the user.
      }
    }
  }

  Future<AuthSession> _loginOrActivateVerifiedUser(
    AuthRepository repository,
    AuthCredentials credentials,
    String firebaseIdToken,
  ) async {
    try {
      return await repository.login(credentials, firebaseIdToken);
    } on ServerException catch (error) {
      if (error.statusCode != 403 || error.code != 'MSG_UNVERIFIED') {
        rethrow;
      }
      return repository.verifyEmail(firebaseIdToken);
    }
  }

  // Role classification is handled by _establishSession/_classifyRole; there is
  // intentionally no fallback that maps an unknown role to Traveler.

  String _identitySignInMessage(
    AuthIdentityFailure failure,
  ) => switch (failure) {
    AuthIdentityFailure.emailUnverified =>
      'Please verify your email before continuing.',
    AuthIdentityFailure.invalidCredentials =>
      'Invalid email or password. Please try again.',
    AuthIdentityFailure.network =>
      'TripMate is temporarily unable to process your request. Please check your connection and try again.',
    AuthIdentityFailure.unavailable =>
      'Sign in is unavailable. Please try again later.',
    _ => 'Unable to sign in. Please try again later.',
  };

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
