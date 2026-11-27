import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/domain/repositories/password_recovery_repository.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/cubit/password_recovery_state.dart';

typedef CooldownStreamFactory = Stream<int> Function(int seconds);
typedef CooldownClock = DateTime Function();

/// Persists active per-email password-reset cooldown deadlines across route
/// navigation (e.g. "Back to sign in" -> "Forgot password?") during the
/// current app session.
final class PasswordRecoveryCooldownTracker {
  PasswordRecoveryCooldownTracker({CooldownClock? clock})
    : _clock = clock ?? DateTime.now;

  final CooldownClock _clock;
  final Map<String, DateTime> _expiresAtByEmail = <String, DateTime>{};

  int remainingSecondsFor(String rawEmail) {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty) return 0;
    final expiresAt = _expiresAtByEmail[email];
    if (expiresAt == null) return 0;
    final remainingMs = expiresAt.difference(_clock()).inMilliseconds;
    if (remainingMs <= 0) {
      _expiresAtByEmail.remove(email);
      return 0;
    }
    return (remainingMs / 1000).ceil();
  }

  void startCooldown(
    String rawEmail, {
    int seconds = PasswordRecoveryCubit.cooldownDurationSeconds,
  }) {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty || seconds <= 0) return;
    _expiresAtByEmail[email] = _clock().add(Duration(seconds: seconds));
  }

  void clearFor(String rawEmail) {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty) return;
    _expiresAtByEmail.remove(email);
  }
}

final class PasswordRecoveryCubit extends Cubit<PasswordRecoveryState> {
  PasswordRecoveryCubit(
    this._repository, {
    CooldownStreamFactory? cooldownStream,
    PasswordRecoveryCooldownTracker? cooldownTracker,
  }) : _cooldownStream = cooldownStream ?? _defaultCooldownStream,
       _cooldownTracker = cooldownTracker ?? PasswordRecoveryCooldownTracker(),
       super(const PasswordRecoveryState());

  static const cooldownDurationSeconds = 60;
  static const requestAcceptedMessage =
      'If a reset code was sent, check your email.';
  static const resendAcceptedMessage =
      'If a new reset code was sent, any previous code may no longer be valid.';
  static const resetSuccessMessage =
      'Your password has been reset. Sign in with your new password.';

  final PasswordRecoveryRepository _repository;
  final CooldownStreamFactory _cooldownStream;
  final PasswordRecoveryCooldownTracker _cooldownTracker;
  StreamSubscription<int>? _cooldownSubscription;

  void clearFieldError(String field) {
    if (isClosed || !state.fieldErrors.containsKey(field)) return;

    final updatedFieldErrors = Map<String, List<String>>.from(state.fieldErrors)
      ..remove(field);
    emit(
      PasswordRecoveryState(
        status: state.status,
        normalizedEmail: state.normalizedEmail,
        feedbackMessage: state.feedbackMessage,
        errorMessage: state.errorMessage,
        fieldErrors: updatedFieldErrors,
        cooldownSeconds: state.cooldownSeconds,
        cooldownEmail: state.cooldownEmail,
        isEditingEmail: state.isEditingEmail,
      ),
    );
  }

  /// Returns to the email step so the user can fix a typo while keeping any
  /// active cooldown intact for the previously requested email.
  void editEmail() {
    if (isClosed || state.isBusy || !state.hasAcceptedRequest) return;
    emit(
      PasswordRecoveryState(
        status: state.cooldownSeconds > 0
            ? PasswordRecoveryStatus.cooldown
            : PasswordRecoveryStatus.idle,
        normalizedEmail: state.normalizedEmail,
        feedbackMessage: state.feedbackMessage,
        cooldownSeconds: state.cooldownSeconds,
        cooldownEmail: state.cooldownEmail,
        isEditingEmail: true,
      ),
    );
  }

  /// Hydrates any active session-level cooldown for [rawEmail] when the user
  /// enters an email on Step 1 (including after navigating "Back to sign in").
  void syncEmailCooldown(String rawEmail) {
    if (isClosed || state.isBusy || state.hasAcceptedRequest) return;
    final normalized = rawEmail.trim().toLowerCase();
    if (normalized.isEmpty) return;

    final remaining = _cooldownTracker.remainingSecondsFor(normalized);
    if (remaining <= 0) return;
    if (state.cooldownEmail == normalized && state.cooldownSeconds > 0) return;

    emit(
      PasswordRecoveryState(
        status: PasswordRecoveryStatus.cooldown,
        normalizedEmail: state.normalizedEmail,
        feedbackMessage: state.feedbackMessage,
        errorMessage: state.errorMessage,
        fieldErrors: state.fieldErrors,
        cooldownSeconds: remaining,
        cooldownEmail: normalized,
        isEditingEmail: state.normalizedEmail != null,
      ),
    );
    _startCooldown(remaining);
  }

  /// Jumps straight to Step 2 for an email that already has an active cooldown
  /// so the user can enter the OTP they received without re-requesting.
  void resumeReset(String rawEmail) {
    if (isClosed || state.isBusy) return;
    final normalized = rawEmail.trim().toLowerCase();
    if (normalized.isEmpty) return;

    final remaining = state.hasActiveCooldownFor(normalized)
        ? state.cooldownSeconds
        : _cooldownTracker.remainingSecondsFor(normalized);
    if (remaining <= 0) return;

    final needsStream =
        _cooldownSubscription == null || state.cooldownEmail != normalized;
    emit(
      PasswordRecoveryState(
        status: PasswordRecoveryStatus.cooldown,
        normalizedEmail: normalized,
        feedbackMessage: state.feedbackMessage ?? requestAcceptedMessage,
        cooldownSeconds: remaining,
        cooldownEmail: normalized,
      ),
    );
    if (needsStream) _startCooldown(remaining);
  }

  Future<bool> requestReset(String email) async {
    if (isClosed || state.isBusy) return false;

    final normalizedEmail = email.trim().toLowerCase();
    // Prevent rapid re-send bypass when returning via "Change email" or
    // "Back to sign in" for the same address while its 60s cooldown is active.
    final activeRemaining = state.hasActiveCooldownFor(normalizedEmail)
        ? state.cooldownSeconds
        : _cooldownTracker.remainingSecondsFor(normalizedEmail);
    if (activeRemaining > 0) {
      final needsStream =
          _cooldownSubscription == null ||
          state.cooldownEmail != normalizedEmail;
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.cooldown,
          normalizedEmail: state.normalizedEmail,
          feedbackMessage: state.feedbackMessage,
          cooldownSeconds: activeRemaining,
          cooldownEmail: normalizedEmail,
          isEditingEmail: state.normalizedEmail != null,
        ),
      );
      if (needsStream) _startCooldown(activeRemaining);
      return false;
    }

    final previousCooldownSeconds = state.cooldownSeconds;
    final previousCooldownEmail = state.cooldownEmail;

    emit(
      PasswordRecoveryState(
        status: PasswordRecoveryStatus.requesting,
        normalizedEmail: normalizedEmail,
        cooldownSeconds: previousCooldownSeconds,
        cooldownEmail: previousCooldownEmail,
      ),
    );

    try {
      await _repository.requestPasswordReset(normalizedEmail);
      if (isClosed) return false;
      _cooldownTracker.startCooldown(normalizedEmail);
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.requestAccepted,
          normalizedEmail: normalizedEmail,
          feedbackMessage: requestAcceptedMessage,
          cooldownSeconds: cooldownDurationSeconds,
          cooldownEmail: normalizedEmail,
        ),
      );
      _startCooldown();
      return true;
    } on Failure catch (failure) {
      if (isClosed) return false;
      final restartCooldown = failure is RateLimitFailure;
      if (restartCooldown) _cooldownTracker.startCooldown(normalizedEmail);
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.failure,
          errorMessage: failure.message,
          fieldErrors: failure is ValidationFailure
              ? failure.fieldErrors
              : const {},
          cooldownSeconds: restartCooldown
              ? cooldownDurationSeconds
              : previousCooldownSeconds,
          cooldownEmail: restartCooldown
              ? normalizedEmail
              : previousCooldownEmail,
        ),
      );
      if (restartCooldown) _startCooldown();
      return false;
    } catch (_) {
      if (isClosed) return false;
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.failure,
          errorMessage: 'Something went wrong. Please try again later.',
          cooldownSeconds: previousCooldownSeconds,
          cooldownEmail: previousCooldownEmail,
        ),
      );
      return false;
    }
  }

  Future<bool> resend() async {
    if (isClosed) return false;
    final email = state.normalizedEmail;
    if (state.isBusy || state.cooldownSeconds > 0 || email == null) {
      return false;
    }

    emit(
      PasswordRecoveryState(
        status: PasswordRecoveryStatus.resending,
        normalizedEmail: email,
        cooldownEmail: email,
      ),
    );
    try {
      await _repository.requestPasswordReset(email);
      if (isClosed) return false;
      _cooldownTracker.startCooldown(email);
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.requestAccepted,
          normalizedEmail: email,
          feedbackMessage: resendAcceptedMessage,
          cooldownSeconds: cooldownDurationSeconds,
          cooldownEmail: email,
        ),
      );
      _startCooldown();
      return true;
    } on Failure catch (failure) {
      if (isClosed) return false;
      final restartCooldown = failure is RateLimitFailure;
      if (restartCooldown) _cooldownTracker.startCooldown(email);
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.failure,
          normalizedEmail: email,
          errorMessage: failure.message,
          fieldErrors: failure is ValidationFailure
              ? failure.fieldErrors
              : const {},
          cooldownSeconds: restartCooldown ? cooldownDurationSeconds : 0,
          cooldownEmail: restartCooldown ? email : null,
        ),
      );
      if (restartCooldown) _startCooldown();
      return false;
    } catch (_) {
      if (isClosed) return false;
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.failure,
          normalizedEmail: email,
          errorMessage: 'Something went wrong. Please try again later.',
        ),
      );
      return false;
    }
  }

  Future<bool> confirmReset({
    required String code,
    required String newPassword,
  }) async {
    if (isClosed) return false;
    final email = state.normalizedEmail;
    if (state.isBusy || email == null) return false;

    emit(
      PasswordRecoveryState(
        status: PasswordRecoveryStatus.confirming,
        normalizedEmail: email,
        cooldownSeconds: state.cooldownSeconds,
        cooldownEmail: state.cooldownEmail,
      ),
    );
    try {
      await _repository.confirmPasswordReset(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      if (isClosed) return false;
      _cooldownTracker.clearFor(email);
      unawaited(_cooldownSubscription?.cancel());
      _cooldownSubscription = null;
      emit(
        const PasswordRecoveryState(
          status: PasswordRecoveryStatus.success,
          feedbackMessage: resetSuccessMessage,
        ),
      );
      return true;
    } on Failure catch (failure) {
      if (isClosed) return false;
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.failure,
          normalizedEmail: email,
          errorMessage: failure.message,
          fieldErrors: failure is ValidationFailure
              ? failure.fieldErrors
              : const {},
          cooldownSeconds: state.cooldownSeconds,
          cooldownEmail: state.cooldownEmail,
        ),
      );
      return false;
    } catch (_) {
      if (isClosed) return false;
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.failure,
          normalizedEmail: email,
          errorMessage: 'Something went wrong. Please try again later.',
          cooldownSeconds: state.cooldownSeconds,
          cooldownEmail: state.cooldownEmail,
        ),
      );
      return false;
    }
  }

  void _startCooldown([int seconds = cooldownDurationSeconds]) {
    unawaited(_cooldownSubscription?.cancel());
    _cooldownSubscription = _cooldownStream(seconds).listen((remaining) {
      if (isClosed || state.status == PasswordRecoveryStatus.success) return;
      final current = state;
      if (remaining <= 0 && current.cooldownEmail != null) {
        _cooldownTracker.clearFor(current.cooldownEmail!);
      }
      final status = switch (current.status) {
        PasswordRecoveryStatus.requesting ||
        PasswordRecoveryStatus.confirming ||
        PasswordRecoveryStatus.resending ||
        PasswordRecoveryStatus.failure => current.status,
        _ =>
          remaining > 0
              ? PasswordRecoveryStatus.cooldown
              : (current.isEditingEmail || current.normalizedEmail == null
                    ? PasswordRecoveryStatus.idle
                    : PasswordRecoveryStatus.requestAccepted),
      };
      emit(
        PasswordRecoveryState(
          status: status,
          normalizedEmail: current.normalizedEmail,
          feedbackMessage: current.feedbackMessage,
          errorMessage: current.errorMessage,
          fieldErrors: current.fieldErrors,
          cooldownSeconds: remaining,
          cooldownEmail: remaining > 0 ? current.cooldownEmail : null,
          isEditingEmail: current.isEditingEmail,
        ),
      );
    });
  }

  static Stream<int> _defaultCooldownStream(int seconds) async* {
    for (var remaining = seconds - 1; remaining >= 0; remaining--) {
      await Future<void>.delayed(const Duration(seconds: 1));
      yield remaining;
    }
  }

  @override
  Future<void> close() async {
    await _cooldownSubscription?.cancel();
    return super.close();
  }
}
