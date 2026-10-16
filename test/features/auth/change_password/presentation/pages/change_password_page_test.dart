import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/change_password/domain/repositories/change_password_repository.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/cubit/change_password_cubit.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/pages/change_password_page.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';

void main() {
  testWidgets('blocks submission and shows inline errors for empty fields', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final cubit = ChangePasswordCubit(repository, _FakeSecureStorage());
    addTearDown(cubit.close);
    await tester.pumpWidget(_testApp(cubit));

    await tester.tap(find.widgetWithText(AppButton, 'Change password'));
    await tester.pump();

    expect(find.text('Current password is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.text('Confirm new password is required.'), findsOneWidget);
    expect(repository.calls, 0);
  });

  testWidgets('blocks submission when new password equals current', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final cubit = ChangePasswordCubit(repository, _FakeSecureStorage());
    addTearDown(cubit.close);
    await tester.pumpWidget(_testApp(cubit));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'SamePass123!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'SamePass123!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'SamePass123!',
    );
    await tester.tap(find.widgetWithText(AppButton, 'Change password'));
    await tester.pump();

    expect(
      find.text('New password must be different from the current password.'),
      findsOneWidget,
    );
    expect(repository.calls, 0);
  });

  testWidgets('blocks submission when confirmation does not match', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final cubit = ChangePasswordCubit(repository, _FakeSecureStorage());
    addTearDown(cubit.close);
    await tester.pumpWidget(_testApp(cubit));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'CurrentPass1!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'NewPass2@aaaa',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'Different3#aaa',
    );
    await tester.tap(find.widgetWithText(AppButton, 'Change password'));
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(repository.calls, 0);
  });

  testWidgets(
    'a valid submit calls the repository once, shows a success snackbar, '
    'and returns to the page it was pushed from',
    (tester) async {
      final repository = _FakeRepository(
        session: const AuthSession(
          userId: 1,
          status: 'Active',
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          role: 'Traveler',
        ),
      );
      final cubit = ChangePasswordCubit(repository, _FakeSecureStorage());
      addTearDown(cubit.close);
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Scaffold(body: Text('Settings page')),
          ),
          GoRoute(
            path: '/change-password',
            builder: (_, _) => BlocProvider<ChangePasswordCubit>.value(
              value: cubit,
              child: const ChangePasswordPage(),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      unawaited(router.push('/change-password'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'CurrentPass1!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'NewPass2@aaaa',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'NewPass2@aaaa',
      );
      await tester.tap(find.widgetWithText(AppButton, 'Change password'));
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(repository.lastCurrentPassword, 'CurrentPass1!');
      expect(repository.lastNewPassword, 'NewPass2@aaaa');
      expect(find.text('Password updated successfully.'), findsOneWidget);
      // Popped back to the page that pushed this route.
      expect(find.text('Settings page'), findsOneWidget);
      expect(find.byType(ChangePasswordPage), findsNothing);
    },
  );

  testWidgets(
    'a direct navigation with no back stack falls back to Traveler Settings on success',
    (tester) async {
      final repository = _FakeRepository(
        session: const AuthSession(
          userId: 1,
          status: 'Active',
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          role: 'Traveler',
        ),
      );
      final changePasswordCubit = ChangePasswordCubit(
        repository,
        _FakeSecureStorage(),
      );
      addTearDown(changePasswordCubit.close);

      final sessionStorage = _FakeSecureStorage(
        seed: {
          AppConstants.keepSignedInKey: 'true',
          AppConstants.accessTokenKey: 'existing-access',
          AppConstants.refreshTokenKey: 'existing-refresh',
          AppConstants.sessionRoleKey: 'traveler',
        },
      );
      final authSessionCubit = AuthSessionCubit(null, sessionStorage);
      await authSessionCubit.restoreSession();
      addTearDown(authSessionCubit.close);

      final router = GoRouter(
        initialLocation: AppRoutes.travelerChangePassword,
        routes: [
          GoRoute(
            path: AppRoutes.travelerChangePassword,
            builder: (_, _) => BlocProvider<ChangePasswordCubit>.value(
              value: changePasswordCubit,
              child: const ChangePasswordPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.travelerSettings,
            builder: (_, _) => const Scaffold(body: Text('Traveler Settings')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthSessionCubit>.value(value: authSessionCubit),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        'CurrentPass1!',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        'NewPass2@aaaa',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm new password'),
        'NewPass2@aaaa',
      );
      await tester.tap(find.widgetWithText(AppButton, 'Change password'));
      await tester.pumpAndSettle();

      // There was no back stack (this route was the initial location); the
      // page must fall back to the Traveler Settings destination rather than
      // stranding the user on Change Password.
      expect(find.text('Traveler Settings'), findsOneWidget);
      expect(find.byType(ChangePasswordPage), findsNothing);
    },
  );

  testWidgets('targets Current Password for an incorrect-password failure', (
    tester,
  ) async {
    final repository = _FakeRepository(errorField: 'currentPassword');
    final cubit = ChangePasswordCubit(repository, _FakeSecureStorage());
    addTearDown(cubit.close);
    await tester.pumpWidget(_testApp(cubit));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Current password'),
      'WrongPass1!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'New password'),
      'NewPass2@aaaa',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirm new password'),
      'NewPass2@aaaa',
    );
    await tester.tap(find.widgetWithText(AppButton, 'Change password'));
    await tester.pumpAndSettle();

    expect(
      find.text('Current password does not match our records.'),
      findsOneWidget,
    );
  });
}

Widget _testApp(ChangePasswordCubit cubit) {
  return MaterialApp(
    home: BlocProvider<ChangePasswordCubit>.value(
      value: cubit,
      child: const ChangePasswordPage(),
    ),
  );
}

final class _FakeSecureStorage implements SecureStorageService {
  _FakeSecureStorage({Map<String, String>? seed}) : _values = {...?seed};

  final Map<String, String> _values;

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> deleteAll() async => _values.clear();

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

final class _FakeRepository implements ChangePasswordRepository {
  _FakeRepository({this.session, this.errorField});

  final AuthSession? session;
  final String? errorField;
  var calls = 0;
  String? lastCurrentPassword;
  String? lastNewPassword;

  @override
  Future<AuthSession> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    calls++;
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    if (errorField == 'currentPassword') {
      throw const IncorrectCurrentPasswordFailure();
    }
    return session!;
  }
}
