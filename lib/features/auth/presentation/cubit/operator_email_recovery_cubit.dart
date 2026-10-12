import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/tour_operator_registration_repository.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/auth_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/services/operator_registration_identity_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/usecases/register_tour_operator.dart';

enum OperatorEmailRecoveryPhase {
  idle,
  sending,
  sent,
  checking,
  verified,
  error,
}

final class OperatorEmailRecoveryState {
  const OperatorEmailRecoveryState({
    this.phase = OperatorEmailRecoveryPhase.idle,
    this.message,
  });

  final OperatorEmailRecoveryPhase phase;
  final String? message;

  bool get isBusy =>
      phase == OperatorEmailRecoveryPhase.sending ||
      phase == OperatorEmailRecoveryPhase.checking;
}

final class OperatorEmailRecoveryCubit
    extends Cubit<OperatorEmailRecoveryState> {
  OperatorEmailRecoveryCubit(this._register)
    : super(const OperatorEmailRecoveryState());

  final RegisterTourOperator _register;

  Future<void> sendEmail({
    required String email,
    required String password,
  }) async {
    if (state.isBusy || state.phase == OperatorEmailRecoveryPhase.verified) {
      return;
    }
    emit(
      const OperatorEmailRecoveryState(
        phase: OperatorEmailRecoveryPhase.sending,
      ),
    );
    try {
      await _register.sendRecoveryVerificationEmail(
        email: email,
        password: password,
      );
      if (isClosed) return;
      emit(
        const OperatorEmailRecoveryState(
          phase: OperatorEmailRecoveryPhase.sent,
          message:
              'Verification email sent. Open the link in your inbox, then return here to check.',
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        OperatorEmailRecoveryState(
          phase: OperatorEmailRecoveryPhase.error,
          message: _safeMessage(error),
        ),
      );
    }
  }

  Future<void> checkEmail({
    required String email,
    required String password,
  }) async {
    if (state.isBusy || state.phase == OperatorEmailRecoveryPhase.verified) {
      return;
    }
    emit(
      const OperatorEmailRecoveryState(
        phase: OperatorEmailRecoveryPhase.checking,
      ),
    );
    try {
      await _register.confirmVerifiedEmail(email, password: password);
      if (isClosed) return;
      emit(
        const OperatorEmailRecoveryState(
          phase: OperatorEmailRecoveryPhase.verified,
          message: 'Email verified. Sign in to check your application status.',
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        OperatorEmailRecoveryState(
          phase: OperatorEmailRecoveryPhase.error,
          message: _safeMessage(error),
        ),
      );
    }
  }

  String _safeMessage(Object error) {
    if (error is OperatorEmailNotVerified) {
      return 'Your email is not verified yet. Open the link in your inbox, then try again.';
    }
    if (error is OperatorRegistrationIdentityMismatch ||
        error is AuthIdentityException &&
            error.failure == AuthIdentityFailure.invalidCredentials) {
      return 'Use the same email and password as your Tour Operator application.';
    }
    if (error is AuthIdentityException) {
      return switch (error.failure) {
        AuthIdentityFailure.network => 'Check your connection and try again.',
        AuthIdentityFailure.tooManyRequests =>
          'Too many attempts. Please wait before trying again.',
        _ => 'The verification service is unavailable. Please try again later.',
      };
    }
    if (error is OperatorVerificationConfigurationFailure) {
      return 'Email verification is not configured. Please contact support.';
    }
    if (error is OperatorVerificationRejected ||
        error is OperatorVerificationUncertain) {
      return 'We could not confirm your email yet. Please try again.';
    }
    return 'TripMate is temporarily unable to process your request. Please try again.';
  }
}
