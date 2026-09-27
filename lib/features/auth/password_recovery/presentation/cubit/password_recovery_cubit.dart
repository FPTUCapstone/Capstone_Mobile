import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/domain/repositories/password_recovery_repository.dart';
import 'package:trip_mate_mobile/features/auth/password_recovery/presentation/cubit/password_recovery_state.dart';

typedef CooldownStreamFactory = Stream<int> Function(int seconds);

final class PasswordRecoveryCubit extends Cubit<PasswordRecoveryState> {
  PasswordRecoveryCubit(
    this._repository, {
    CooldownStreamFactory? cooldownStream,
  }) : _cooldownStream = cooldownStream ?? _defaultCooldownStream,
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
      ),
    );
  }

  Future<bool> requestReset(String email) async {
    if (isClosed || state.isBusy) return false;

    final normalizedEmail = email.trim().toLowerCase();
    emit(
      PasswordRecoveryState(
        status: PasswordRecoveryStatus.requesting,
        normalizedEmail: normalizedEmail,
      ),
    );

    try {
      await _repository.requestPasswordReset(normalizedEmail);
      if (isClosed) return false;
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.requestAccepted,
          normalizedEmail: normalizedEmail,
          feedbackMessage: requestAcceptedMessage,
          cooldownSeconds: cooldownDurationSeconds,
        ),
      );
      _startCooldown();
      return true;
    } on Failure catch (failure) {
      if (isClosed) return false;
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.failure,
          errorMessage: failure.message,
          fieldErrors: failure is ValidationFailure
              ? failure.fieldErrors
              : const {},
        ),
      );
      return false;
    } catch (_) {
      if (isClosed) return false;
      emit(
        const PasswordRecoveryState(
          status: PasswordRecoveryStatus.failure,
          errorMessage: 'Something went wrong. Please try again later.',
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
      ),
    );
    try {
      await _repository.requestPasswordReset(email);
      if (isClosed) return false;
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.requestAccepted,
          normalizedEmail: email,
          feedbackMessage: resendAcceptedMessage,
          cooldownSeconds: cooldownDurationSeconds,
        ),
      );
      _startCooldown();
      return true;
    } on Failure catch (failure) {
      if (isClosed) return false;
      final restartCooldown = failure is RateLimitFailure;
      emit(
        PasswordRecoveryState(
          status: PasswordRecoveryStatus.failure,
          normalizedEmail: email,
          errorMessage: failure.message,
          fieldErrors: failure is ValidationFailure
              ? failure.fieldErrors
              : const {},
          cooldownSeconds: restartCooldown ? cooldownDurationSeconds : 0,
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
      ),
    );
    try {
      await _repository.confirmPasswordReset(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      if (isClosed) return false;
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
        ),
      );
      return false;
    }
  }

  void _startCooldown() {
    unawaited(_cooldownSubscription?.cancel());
    _cooldownSubscription = _cooldownStream(cooldownDurationSeconds).listen((
      seconds,
    ) {
      if (isClosed || state.status == PasswordRecoveryStatus.success) return;
      final current = state;
      final status = switch (current.status) {
        PasswordRecoveryStatus.requesting ||
        PasswordRecoveryStatus.confirming ||
        PasswordRecoveryStatus.resending ||
        PasswordRecoveryStatus.failure => current.status,
        _ =>
          seconds > 0
              ? PasswordRecoveryStatus.cooldown
              : PasswordRecoveryStatus.requestAccepted,
      };
      emit(
        PasswordRecoveryState(
          status: status,
          normalizedEmail: current.normalizedEmail,
          feedbackMessage: current.feedbackMessage,
          errorMessage: current.errorMessage,
          fieldErrors: current.fieldErrors,
          cooldownSeconds: seconds,
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
