import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/auth/presentation/demo/auth_demo_data.dart';

enum PasswordDemoStatus { idle, loading, success, failure }

final class PasswordDemoState extends Equatable {
  const PasswordDemoState({
    this.message,
    this.status = PasswordDemoStatus.idle,
  });

  final String? message;
  final PasswordDemoStatus status;

  bool get isLoading => status == PasswordDemoStatus.loading;

  @override
  List<Object?> get props => [status, message];
}

final class PasswordDemoCubit extends Cubit<PasswordDemoState> {
  PasswordDemoCubit() : super(const PasswordDemoState());

  Future<void> resetPassword({
    required String code,
    required String password,
  }) async {
    if (code.trim() != AuthDemoData.verificationCode) {
      emit(
        const PasswordDemoState(
          status: PasswordDemoStatus.failure,
          message: 'The verification code is invalid. Use 123456 for the demo.',
        ),
      );
      return;
    }
    await _complete('Password reset successfully.');
  }

  Future<void> changePassword({required String currentPassword}) async {
    if (currentPassword != AuthDemoData.password) {
      emit(
        const PasswordDemoState(
          status: PasswordDemoStatus.failure,
          message: 'Current password is incorrect for this demo account.',
        ),
      );
      return;
    }
    await _complete('Password updated successfully.');
  }

  Future<void> _complete(String message) async {
    emit(const PasswordDemoState(status: PasswordDemoStatus.loading));
    await Future<void>.delayed(const Duration(milliseconds: 450));
    emit(
      PasswordDemoState(status: PasswordDemoStatus.success, message: message),
    );
  }
}
