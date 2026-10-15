import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/change_password/domain/repositories/change_password_repository.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/cubit/change_password_state.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';

/// Internal marker for a partial local-storage replace: the Backend already
/// committed the new password, but this device could not persist the full
/// replacement session. Caught separately so the UI gets a distinct,
/// actionable message instead of the generic fallback.
final class _SessionReplaceFailedException implements Exception {
  const _SessionReplaceFailedException();
}

/// UC-07: replaces the authenticated account's local password. On success,
/// the replacement access/refresh tokens are persisted to secure storage
/// exactly once (atomic replace); role, application status, and the
/// existing keep-signed-in gate are untouched because this flow never
/// changes them. A failed or malformed response leaves the previous session
/// intact.
final class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  ChangePasswordCubit(this._repository, this._secureStorage)
    : super(const ChangePasswordState());

  final ChangePasswordRepository _repository;
  final SecureStorageService _secureStorage;

  Future<bool> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (isClosed || state.isSubmitting) return false;

    emit(const ChangePasswordState(status: ChangePasswordStatus.submitting));

    try {
      final session = await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await _replaceSessionTokensOrRollback(session);
      if (isClosed) return false;
      emit(const ChangePasswordState(status: ChangePasswordStatus.success));
      return true;
    } on Failure catch (failure) {
      if (isClosed) return false;
      final fieldErrors = switch (failure) {
        IncorrectCurrentPasswordFailure() => {
          'currentPassword': [failure.message],
        },
        ValidationFailure() => failure.fieldErrors,
        _ => const <String, List<String>>{},
      };
      emit(
        ChangePasswordState(
          status: ChangePasswordStatus.failure,
          // A field-targeted error is shown inline only; a generic banner
          // repeating the identical text would be redundant (and, for the
          // password-reset precedent, the two messages are meant to differ).
          errorMessage: fieldErrors.isEmpty ? failure.message : null,
          fieldErrors: fieldErrors,
        ),
      );
      return false;
    } on _SessionReplaceFailedException {
      if (isClosed) return false;
      emit(
        const ChangePasswordState(
          status: ChangePasswordStatus.failure,
          errorMessage:
              'Your password was changed, but we could not refresh your '
              'session on this device. Please sign in again.',
        ),
      );
      return false;
    } catch (_) {
      if (isClosed) return false;
      emit(
        const ChangePasswordState(
          status: ChangePasswordStatus.failure,
          errorMessage: 'Something went wrong. Please try again later.',
        ),
      );
      return false;
    }
  }

  /// Replaces the access and refresh tokens as a single unit. If the second
  /// write fails after the first succeeded, this restores both keys to their
  /// prior values (best effort) rather than leaving a mismatched pair, then
  /// throws [_SessionReplaceFailedException]. Note: the Backend has already
  /// revoked every pre-change refresh token server-side, so the restored
  /// pair is a consistent *local* snapshot, not necessarily one the Backend
  /// will still accept — the user may still need to sign in again.
  Future<void> _replaceSessionTokensOrRollback(AuthSession session) async {
    final previousAccessToken = await _secureStorage.read(
      AppConstants.accessTokenKey,
    );
    final previousRefreshToken = await _secureStorage.read(
      AppConstants.refreshTokenKey,
    );

    try {
      await _secureStorage.write(
        AppConstants.accessTokenKey,
        session.accessToken,
      );
      await _secureStorage.write(
        AppConstants.refreshTokenKey,
        session.refreshToken,
      );
    } catch (_) {
      await _restoreBestEffort(
        AppConstants.accessTokenKey,
        previousAccessToken,
      );
      await _restoreBestEffort(
        AppConstants.refreshTokenKey,
        previousRefreshToken,
      );
      throw const _SessionReplaceFailedException();
    }
  }

  Future<void> _restoreBestEffort(String key, String? value) async {
    try {
      if (value == null) {
        await _secureStorage.delete(key);
      } else {
        await _secureStorage.write(key, value);
      }
    } catch (_) {
      // Best effort only; the caller has already decided this is a failure.
    }
  }

  void clearFieldError(String field) {
    if (isClosed || !state.fieldErrors.containsKey(field)) return;
    final updated = Map<String, List<String>>.from(state.fieldErrors)
      ..remove(field);
    emit(
      ChangePasswordState(
        status: state.status,
        errorMessage: state.errorMessage,
        fieldErrors: updated,
      ),
    );
  }
}
