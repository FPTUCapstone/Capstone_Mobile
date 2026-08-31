import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/auth/presentation/demo/auth_demo_data.dart';

void main() {
  group('AuthSessionCubit', () {
    test('starts unauthenticated', () {
      final cubit = AuthSessionCubit();
      addTearDown(cubit.close);

      expect(cubit.state, const AuthSessionState.unauthenticated());
    });

    blocTest<AuthSessionCubit, AuthSessionState>(
      'emits a Traveler preview session and can clear it',
      build: AuthSessionCubit.new,
      act: (cubit) {
        cubit
          ..previewAs(UserRole.traveler)
          ..clearPreviewSession();
      },
      expect: () => const [
        AuthSessionState.authenticated(UserRole.traveler),
        AuthSessionState.unauthenticated(),
      ],
    );

    blocTest<AuthSessionCubit, AuthSessionState>(
      'authenticates the local Traveler demo account',
      build: AuthSessionCubit.new,
      act: (cubit) => cubit.signIn(
        email: AuthDemoData.traveler.email,
        password: AuthDemoData.password,
      ),
      wait: const Duration(milliseconds: 500),
      expect: () => const [
        AuthSessionState.loading(),
        AuthSessionState.authenticated(
          UserRole.traveler,
          accountType: DemoAccountType.traveler,
        ),
      ],
    );
  });
}
