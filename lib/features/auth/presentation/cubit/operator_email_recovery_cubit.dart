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
              'Đã gửi email xác minh. Hãy mở liên kết trong hộp thư rồi quay lại đây để kiểm tra.',
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
          message:
              'Đã xác minh email. Vui lòng đăng nhập để kiểm tra trạng thái hồ sơ đối tác.',
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
      return 'Email của bạn chưa được xác minh. Hãy mở liên kết trong hộp thư rồi thử lại.';
    }
    if (error is OperatorRegistrationIdentityMismatch ||
        error is AuthIdentityException &&
            error.failure == AuthIdentityFailure.invalidCredentials) {
      return 'Vui lòng sử dụng đúng email và mật khẩu của hồ sơ nhà điều hành tour.';
    }
    if (error is AuthIdentityException) {
      return switch (error.failure) {
        AuthIdentityFailure.network =>
          'Vui lòng kiểm tra kết nối mạng và thử lại.',
        AuthIdentityFailure.tooManyRequests =>
          'Bạn thao tác quá nhiều lần. Vui lòng đợi rồi thử lại.',
        _ => 'Dịch vụ xác minh hiện không khả dụng. Vui lòng thử lại sau.',
      };
    }
    if (error is OperatorVerificationConfigurationFailure) {
      return 'Chức năng xác minh email chưa được cấu hình. Vui lòng liên hệ bộ phận hỗ trợ.';
    }
    if (error is OperatorVerificationRejected ||
        error is OperatorVerificationUncertain) {
      return 'Chưa thể xác nhận email của bạn lúc này. Vui lòng thử lại.';
    }
    return 'TripMate tạm thời không thể xử lý yêu cầu của bạn. Vui lòng thử lại.';
  }
}
