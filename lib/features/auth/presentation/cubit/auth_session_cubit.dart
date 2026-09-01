import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/auth/presentation/demo/auth_demo_data.dart';

final class AuthSessionCubit extends Cubit<AuthSessionState> {
  AuthSessionCubit() : super(const AuthSessionState.unauthenticated());

  void clearPreviewSession() => clearSession();

  void clearSession() => emit(const AuthSessionState.unauthenticated());

  void previewAs(UserRole role) => emit(AuthSessionState.authenticated(role));

  Future<void> signIn({required String email, required String password}) async {
    emit(const AuthSessionState.loading());
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final account = AuthDemoData.authenticate(email, password);
    if (account == null) {
      emit(
        const AuthSessionState.failure(
          'Email or password is incorrect. Please try again.',
        ),
      );
      return;
    }
    emit(
      AuthSessionState.authenticated(account.role, accountType: account.type),
    );
  }

  Future<void> signInWithDemoCode(String code) async {
    emit(const AuthSessionState.loading());
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (code.trim() != AuthDemoData.verificationCode) {
      emit(const AuthSessionState.failure('Enter the demo code 123456.'));
      return;
    }
    emit(
      const AuthSessionState.authenticated(
        UserRole.traveler,
        accountType: DemoAccountType.traveler,
      ),
    );
  }
}
