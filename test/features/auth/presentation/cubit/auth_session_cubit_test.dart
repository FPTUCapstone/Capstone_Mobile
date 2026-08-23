import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/user_role.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';

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
  });
}
