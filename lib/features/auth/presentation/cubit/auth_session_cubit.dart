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
    final storage = _secureStorage;
    if (storage != null) {
      await _clearStoredSession(storage);
    }
    await _firebaseAuthService?.signOut();
    emit(const AuthSessionState.unauthenticated());
  }

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
