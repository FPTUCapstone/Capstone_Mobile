import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/core/error/failures.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/change_password/domain/repositories/change_password_repository.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/cubit/change_password_cubit.dart';
import 'package:trip_mate_mobile/features/auth/change_password/presentation/pages/change_password_page.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
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
    'a valid submit calls the repository exactly once and shows success',
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
        'NewPass2@aaaa',
      );
      await tester.tap(find.widgetWithText(AppButton, 'Change password'));
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(repository.lastCurrentPassword, 'CurrentPass1!');
      expect(repository.lastNewPassword, 'NewPass2@aaaa');
      expect(find.text('Password updated successfully.'), findsOneWidget);
      // Fields are cleared after success.
      expect(find.widgetWithText(TextFormField, 'CurrentPass1!'), findsNothing);
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
  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
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
