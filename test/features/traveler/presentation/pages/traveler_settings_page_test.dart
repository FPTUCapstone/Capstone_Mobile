import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_settings_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';
import 'package:trip_mate_mobile/shared/widgets/app_button.dart';

const _dialogTitle = 'Sign out of TripMate?';
const _dialogBody =
    'Your session on this device will end. Downloaded offline trips stay on the device.';

Future<AuthSessionCubit> _authenticatedCubit({
  _RecordingAuthRepository? repository,
  _MemoryStorage? storage,
}) async {
  final cubit = AuthSessionCubit(
    repository ?? _RecordingAuthRepository(),
    storage ??
        _MemoryStorage({
          AppConstants.accessTokenKey: 'access',
          AppConstants.refreshTokenKey: 'refresh',
          AppConstants.sessionRoleKey: 'traveler',
          AppConstants.keepSignedInKey: 'true',
        }),
  );
  await cubit.restoreSession();
  expect(cubit.state.isAuthenticated, isTrue);
  return cubit;
}

Future<void> _pumpSettings(WidgetTester tester, AuthSessionCubit cubit) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider<AuthSessionCubit>.value(
        value: cubit,
        child: const TravelerSettingsPage(),
      ),
    ),
  );
}

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byType(OutlinedButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('settings keeps the existing sign-out confirmation dialog', (
    tester,
  ) async {
    final cubit = await _authenticatedCubit();
    addTearDown(cubit.close);
    await _pumpSettings(tester, cubit);

    await _openDialog(tester);

    expect(find.text(_dialogTitle), findsOneWidget);
    expect(find.text(_dialogBody), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Sign out'), findsOneWidget);
  });

  testWidgets('cancel closes the dialog without any sign-out or backend call', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();
    final cubit = await _authenticatedCubit(repository: repository);
    addTearDown(cubit.close);
    await _pumpSettings(tester, cubit);

    await _openDialog(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text(_dialogTitle), findsNothing);
    expect(repository.logoutCalls, 0);
    expect(cubit.state.isAuthenticated, isTrue);
  });

  testWidgets('confirm uses the backend-integrated flow exactly once', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();
    final cubit = await _authenticatedCubit(repository: repository);
    addTearDown(cubit.close);
    await _pumpSettings(tester, cubit);

    await _openDialog(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(repository.logoutCalls, 1);
    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    expect(find.text(_dialogTitle), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('settings sign-out control is disabled while in flight', (
    tester,
  ) async {
    final completer = Completer<void>();
    final repository = _RecordingAuthRepository(logoutCompleter: completer);
    final cubit = await _authenticatedCubit(repository: repository);
    addTearDown(cubit.close);
    await _pumpSettings(tester, cubit);

    await _openDialog(tester);
    await tester.tap(find.widgetWithText(AppButton, 'Sign out'));
    await tester.pumpAndSettle();

    // Busy state comes from the approved Cubit marker, not a page flag.
    expect(cubit.state.operation, AuthSessionOperation.signOut);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );

    // A second tap cannot open another dialog nor issue another intent.
    await tester.tap(find.byType(OutlinedButton), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(_dialogTitle), findsNothing);
    expect(repository.logoutCalls, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
  });

  testWidgets(
    'settings renders the local-cleanup notice once and never the M3 copy',
    (tester) async {
      final storage = _MemoryStorage({
        AppConstants.accessTokenKey: 'access',
        AppConstants.refreshTokenKey: 'refresh',
        AppConstants.sessionRoleKey: 'traveler',
        AppConstants.keepSignedInKey: 'true',
      });
      final cubit = await _authenticatedCubit(storage: storage);
      addTearDown(cubit.close);
      storage.permanentMutationFailures.addAll({
        AppConstants.accessTokenKey,
        AppConstants.refreshTokenKey,
        AppConstants.sessionRoleKey,
        AppConstants.keepSignedInKey,
      });

      await cubit.signOut();
      await _pumpSettings(tester, cubit);

      expect(cubit.state.status, AuthSessionStatus.authenticated);
      expect(find.byType(AppAlert), findsOneWidget);
      expect(
        find.text(AuthSessionCubit.signOutLocalCleanupFailureMessage),
        findsOneWidget,
      );
      // M3 must never appear on a state where the local sign-out is unproven.
      expect(
        find.text(AuthSessionCubit.signOutRemoteFailureMessage),
        findsNothing,
      );
    },
  );
}

final class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({this.logoutCompleter});

  final Completer<void>? logoutCompleter;
  var logoutCalls = 0;

  @override
  Future<void> logout(String? refreshToken) async {
    logoutCalls += 1;
    if (logoutCompleter != null) {
      await logoutCompleter!.future;
    }
  }

  @override
  Future<AuthSession> googleAuth(String firebaseIdToken) =>
      throw UnimplementedError();

  @override
  Future<AuthSession> login(
    AuthCredentials credentials, [
    String? firebaseIdToken,
  ]) => throw UnimplementedError();

  @override
  Future<TravelerRegistrationResult> registerTraveler(
    TravelerRegistration registration,
    String firebaseIdToken,
  ) => throw UnimplementedError();

  @override
  Future<AuthSession> verifyEmail(String firebaseIdToken) =>
      throw UnimplementedError();
}

final class _MemoryStorage implements SecureStorageService {
  _MemoryStorage(this.values);

  final Map<String, String> values;

  /// Keys whose mutation (delete or write) throws, to exercise the M7
  /// local-cleanup-failure branch deterministically.
  final permanentMutationFailures = <String>{};

  @override
  Future<void> delete(String key) async {
    if (permanentMutationFailures.contains(key)) {
      throw StateError('delete failed');
    }
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (permanentMutationFailures.contains(key)) {
      throw StateError('write failed');
    }
    values[key] = value;
  }
}
