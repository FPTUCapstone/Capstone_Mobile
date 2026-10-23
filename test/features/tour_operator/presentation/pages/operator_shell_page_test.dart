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
import 'package:trip_mate_mobile/features/tour_operator/presentation/pages/operator_shell_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';

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
          AppConstants.sessionRoleKey: 'tourOperator',
          AppConstants.keepSignedInKey: 'true',
        }),
  );
  await cubit.restoreSession();
  expect(cubit.state.isAuthenticated, isTrue);
  return cubit;
}

Future<void> _pumpShell(
  WidgetTester tester,
  AuthSessionCubit cubit, {
  bool isDemoMode = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: BlocProvider<AuthSessionCubit>.value(
        value: cubit,
        child: OperatorShellPage(isDemoMode: isDemoMode),
      ),
    ),
  );
}

void main() {
  testWidgets('operator shell sign-out uses the backend-integrated flow once', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();
    final cubit = await _authenticatedCubit(repository: repository);
    addTearDown(cubit.close);
    await _pumpShell(tester, cubit);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.logout));
    await tester.pumpAndSettle();

    expect(repository.logoutCalls, 1);
    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
    // The existing one-tap UX stays unchanged: no confirmation step.
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('operator Profile tab still offers the change-password entry', (
    tester,
  ) async {
    final cubit = await _authenticatedCubit();
    addTearDown(cubit.close);
    await _pumpShell(tester, cubit);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Change password'), findsOneWidget);
  });

  testWidgets('operator Tours tab offers the create-tour-package entry', (
    tester,
  ) async {
    final cubit = await _authenticatedCubit();
    addTearDown(cubit.close);
    await _pumpShell(tester, cubit);

    await tester.tap(find.text('Tours'));
    await tester.pumpAndSettle();

    expect(find.text('Create tour package'), findsOneWidget);
  });

  testWidgets('operator shell sign-out action is disabled while in flight', (
    tester,
  ) async {
    final completer = Completer<void>();
    final repository = _RecordingAuthRepository(logoutCompleter: completer);
    final cubit = await _authenticatedCubit(repository: repository);
    addTearDown(cubit.close);
    await _pumpShell(tester, cubit);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.logout));
    await tester.pump();

    // Busy state is derived from the approved Cubit marker, not a page flag.
    expect(cubit.state.operation, AuthSessionOperation.signOut);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.logout))
          .onPressed,
      isNull,
    );

    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.logout),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(repository.logoutCalls, 1);

    completer.complete();
    await tester.pumpAndSettle();
    expect(cubit.state.status, AuthSessionStatus.unauthenticated);
  });

  testWidgets(
    'operator shell renders the local-cleanup notice once and never the M3 copy',
    (tester) async {
      final storage = _MemoryStorage({
        AppConstants.accessTokenKey: 'access',
        AppConstants.refreshTokenKey: 'refresh',
        AppConstants.sessionRoleKey: 'tourOperator',
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
      await _pumpShell(tester, cubit);

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

  testWidgets(
    'operator shell in production mode shows truthful pending status without hardcoded finance or bookings',
    (tester) async {
      final cubit = await _authenticatedCubit();
      addTearDown(cubit.close);
      await _pumpShell(tester, cubit, isDemoMode: false);

      // On Dashboard in production:
      // Hardcoded fake revenue or fake bookings must NOT appear as real data
      expect(find.text('38.500.000 đ'), findsNothing);
      expect(find.text('Nguyễn Văn An'), findsNothing);
      expect(find.text('BK-2026-901'), findsNothing);
      expect(find.text('Chờ kết nối API'), findsWidgets);

      // Navigate to Bookings tab
      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có đơn đặt tour'), findsOneWidget);
      expect(
        find.text(
          'Tính năng quản lý danh sách hành khách và đơn đặt chỗ đang chờ kết nối API hệ thống (PENDING_BE_INTEGRATION).',
        ),
        findsOneWidget,
      );

      // Navigate to Revenue tab
      await tester.tap(find.text('Revenue'));
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo doanh thu & Quyết toán'), findsOneWidget);
      expect(
        find.text(
          'Dữ liệu doanh thu, số dư tài khoản và lịch sử quyết toán đối tác đang chờ kết nối cổng thanh toán máy chủ (PENDING_BE_INTEGRATION).',
        ),
        findsOneWidget,
      );

      // Navigate to Coupons tab
      await tester.tap(find.text('Coupons'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có mã khuyến mãi'), findsOneWidget);
    },
  );

  testWidgets(
    'operator shell in demo mode isolates fixtures with prominent demo badge',
    (tester) async {
      final cubit = await _authenticatedCubit();
      addTearDown(cubit.close);
      await _pumpShell(tester, cubit, isDemoMode: true);

      // On Dashboard in demo mode: demo banner is prominent
      expect(
        find.text(
          '[DỮ LIỆU THỬ NGHIỆM - DEMO] Chỉ số tài chính & đơn đặt chỗ dưới đây là dữ liệu mẫu.',
        ),
        findsOneWidget,
      );
      expect(find.text('38.500.000 đ'), findsOneWidget);

      // Navigate to Bookings tab in demo mode
      await tester.tap(find.text('Bookings'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '[DỮ LIỆU THỬ NGHIỆM - DEMO] Danh sách khách hàng và mã đặt chỗ là dữ liệu mẫu.',
        ),
        findsOneWidget,
      );
      expect(find.text('BK-2026-901'), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);

      // Navigate to Revenue tab in demo mode
      await tester.tap(find.text('Revenue'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '[DỮ LIỆU THỬ NGHIỆM - DEMO] Số dư khả dụng và lịch sử giao dịch dưới đây là dữ liệu mẫu.',
        ),
        findsOneWidget,
      );

      // Navigate to Coupons tab in demo mode
      await tester.tap(find.text('Coupons'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '[DỮ LIỆU THỬ NGHIỆM - DEMO] Danh sách mã giảm giá dưới đây là dữ liệu mẫu.',
        ),
        findsOneWidget,
      );
      expect(find.text('DANANG2026'), findsOneWidget);
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
