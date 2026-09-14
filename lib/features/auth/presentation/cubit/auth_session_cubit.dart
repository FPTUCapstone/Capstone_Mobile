import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/exceptions.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/data/models/login_request.dart';
import 'package:trip_mate_mobile/features/auth/data/models/session_response_dto.dart';
import 'package:trip_mate_mobile/features/auth/data/services/firebase_auth_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

final class AuthSessionCubit extends Cubit<AuthSessionState> {
  AuthSessionCubit([
    this._authRepository,
    this._secureStorage,
    this._firebaseAuthService,
  ]) : super(const AuthSessionState.unauthenticated());

  final AuthRepository? _authRepository;
  final SecureStorageService? _secureStorage;
  final FirebaseAuthService? _firebaseAuthService;
  bool _verificationActionInProgress = false;

  Future<String?> get currentFirebaseUserEmail async =>
      _firebaseAuthService?.currentUserEmail;

  Future<void> clearSession() async {
    debugPrint('[AUTH-SESSION] clearSession requested');
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
      emit(AuthSessionState.authenticated(role));
      debugPrint('[AUTH-SESSION] stored session restored; role=${role.name}');
      return;
    }

    await _clearStoredSession(storage);
  }

  void authenticateSession(UserRole role) =>
      emit(AuthSessionState.authenticated(role));

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
      final request = LoginRequest(email: normalizedEmail, password: password);
      final response = await _loginOrActivateVerifiedUser(
        repository,
        request,
        firebaseIdToken,
      );
      final role = _roleFrom(response);
      await _saveSession(
        storage,
        response,
        role: role,
        keepSignedIn: keepSignedIn,
      );
      emit(AuthSessionState.authenticated(role));
      debugPrint(
        '[AUTH-SESSION] backend session accepted; '
        'state=authenticated role=${role.name}',
      );
    } on AppException catch (error) {
      emit(AuthSessionState.failure(error.message));
    } on FirebaseAuthException catch (error) {
      emit(AuthSessionState.failure(_firebaseSignInMessage(error.code)));
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
      await storage.write(AppConstants.accessTokenKey, response.accessToken);
      await storage.write(AppConstants.refreshTokenKey, response.refreshToken);
      emit(AuthSessionState.authenticated(_roleFrom(response)));
    } on AppException catch (error) {
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
    } on FirebaseAuthException catch (error) {
      emit(
        AuthSessionState.failure(
          _firebaseVerificationMessage(error.code, isResend: true),
          startResendCooldown: error.code == 'too-many-requests',
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
      final role = _roleFrom(response);
      await _saveSession(storage, response, role: role);
      emit(AuthSessionState.authenticated(role));
      debugPrint(
        '[AUTH-SESSION] verify-email session accepted; '
        'state=authenticated role=${role.name}',
      );
    } on AppException catch (error) {
      emit(AuthSessionState.failure(error.message));
    } on FirebaseAuthException catch (error) {
      emit(
        AuthSessionState.failure(
          _firebaseVerificationMessage(error.code, isResend: false),
        ),
      );
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

  Future<void> _saveSession(
    SecureStorageService storage,
    SessionResponseDto response, {
    required UserRole role,
    bool keepSignedIn = true,
  }) async {
    await storage.write(AppConstants.accessTokenKey, response.accessToken);
    await storage.write(AppConstants.refreshTokenKey, response.refreshToken);
    await storage.write(AppConstants.sessionRoleKey, role.name);
    await storage.write(AppConstants.keepSignedInKey, keepSignedIn.toString());
  }

  Future<void> _clearStoredSession(SecureStorageService storage) async {
    await storage.delete(AppConstants.accessTokenKey);
    await storage.delete(AppConstants.refreshTokenKey);
    await storage.delete(AppConstants.sessionRoleKey);
    await storage.delete(AppConstants.keepSignedInKey);
  }

  Future<SessionResponseDto> _loginOrActivateVerifiedUser(
    AuthRepository repository,
    LoginRequest request,
    String firebaseIdToken,
  ) async {
    try {
      return await repository.login(request, firebaseIdToken);
    } on ServerException catch (error) {
      if (error.statusCode != 403 || error.code != 'MSG_UNVERIFIED') {
        rethrow;
      }
      return repository.verifyEmail(firebaseIdToken);
    }
  }

  UserRole _roleFrom(SessionResponseDto response) =>
      response.role == 'TourOperator'
      ? UserRole.tourOperator
      : UserRole.traveler;

  String _firebaseSignInMessage(String code) => switch (code) {
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-email' => 'Invalid email or password. Please try again.',
    'network-request-failed' =>
      'TripMate is temporarily unable to process your request. Please check your connection and try again.',
    _ => 'Unable to sign in. Please try again later.',
  };

  String _firebaseVerificationMessage(
    String code, {
    required bool isResend,
  }) => switch (code) {
    'too-many-requests' =>
      'Too many resend attempts. Please wait a few minutes before trying again.',
    'no-current-user' || 'user-not-found' =>
      isResend
          ? 'Your verification session has expired. Please sign in to request a new verification link.'
          : 'Your verification session has expired. Please sign in and request a new verification link.',
    'network-request-failed' =>
      'TripMate is temporarily unable to process your request. Please check your connection and try again.',
    _ =>
      isResend
          ? 'Unable to send verification email. Please try again later or sign in.'
          : 'Email verification could not be completed. Please try again.',
  };
}
