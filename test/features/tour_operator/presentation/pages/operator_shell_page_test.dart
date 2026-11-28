import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_mate_mobile/app/theme/app_theme.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_credentials.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/auth_session.dart';
import 'package:trip_mate_mobile/features/auth/domain/entities/traveler_registration.dart';
import 'package:trip_mate_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_state.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/models/operator_bookings_json.dart';
import 'package:trip_mate_mobile/features/operator_bookings/data/repositories/demo_operator_bookings_repository.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/entities/operator_booking.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/repositories/operator_bookings_repository.dart';
import 'package:trip_mate_mobile/features/operator_bookings/domain/usecases/operator_bookings_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_bookings/presentation/cubit/operator_bookings_cubit.dart';
import 'package:trip_mate_mobile/features/operator_bookings/resources/operator_bookings_en.dart';
import 'package:trip_mate_mobile/features/operator_finance/data/repositories/demo_operator_finance_repository.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_revenue_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_settlement_history_cubit.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/entities/weather_safety_review.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/repositories/operator_weather_safety_realtime.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/domain/usecases/operator_weather_safety_use_cases.dart';
import 'package:trip_mate_mobile/features/operator_weather_safety/presentation/cubit/operator_safety_reviews_cubit.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/entities/operator_dashboard_metrics.dart';
import 'package:trip_mate_mobile/features/tour_operator/domain/repositories/operator_dashboard_repository.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/cubit/operator_dashboard_cubit.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/pages/operator_shell_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_alert.dart';

import '../../../operator_bookings/operator_bookings_fixtures.dart';
import '../../../operator_weather_safety/support/fake_operator_weather_safety_repository.dart';

final class _DashboardRepository implements OperatorDashboardRepository {
  @override
  Future<OperatorDashboardMetrics> load() async => OperatorDashboardMetrics(
    activeTourCount: 2,
    monthlyBookingCount: 3,
    monthlyNetAmount: 10000,
    activeCouponCount: 1,
    asOfUtc: DateTime.utc(2026, 11, 19),
    monthStart: DateTime(2026, 11),
    monthEndExclusive: DateTime(2026, 12),
  );
}

final class _CountingRealtime implements OperatorWeatherSafetyRealtime {
  int starts = 0;
  int stops = 0;

  @override
  Stream<bool> get connection => const Stream.empty();

  @override
  Stream<WeatherSafetyReviewHint> get hints => const Stream.empty();

  @override
  Future<void> start() async => starts++;

  @override
  Future<void> stop() async => stops++;
}

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

/// A live repository that answers one booking and records every request, so a test can see when the
/// Bookings tab starts loading.
final class _SpyBookingsRepository implements OperatorBookingsRepository {
  final List<OperatorBookingsQuery> pageQueries = [];

  @override
  Future<OperatorBookingsPage> getPage(OperatorBookingsQuery query) async {
    pageQueries.add(query);
    return OperatorBookingsJson.page(listPageJson());
  }

  @override
  Future<OperatorBookingDetail> getDetail(String bookingId) =>
      throw UnimplementedError();

  @override
  Future<List<OperatorBookingTourOption>> getTourOptions() async => const [];
}

void main() {
  late _SpyBookingsRepository bookings;
  late List<bool> requestedDemoFlags;

  setUp(() {
    bookings = _SpyBookingsRepository();
    serviceLocator.registerFactoryParam<OperatorRevenueCubit, bool, void>(
      (demo, _) => OperatorRevenueCubit(const DemoOperatorFinanceRepository()),
    );
    serviceLocator
        .registerFactoryParam<OperatorSettlementHistoryCubit, bool, void>(
          (demo, _) => OperatorSettlementHistoryCubit(
            const DemoOperatorFinanceRepository(),
          ),
        );
    serviceLocator.registerFactory<OperatorDashboardCubit>(
      () => OperatorDashboardCubit(_DashboardRepository()),
    );
    requestedDemoFlags = [];
    serviceLocator.registerFactoryParam<OperatorBookingsCubit, bool, void>((
      isDemoMode,
      _,
    ) {
      requestedDemoFlags.add(isDemoMode);
      final OperatorBookingsRepository repository = isDemoMode
          ? const DemoOperatorBookingsRepository()
          : bookings;
      return OperatorBookingsCubit(
        listBookings: ListOperatorBookingsUseCase(repository),
        loadTourOptions: LoadOperatorBookingTourOptionsUseCase(repository),
      );
    });
  });

  tearDown(() => serviceLocator.reset());

  group('UC-70 Safety Alerts', () {
    late FakeOperatorWeatherSafetyRepository safety;
    late _CountingRealtime realtime;

    setUp(() {
      safety = FakeOperatorWeatherSafetyRepository();
      realtime = _CountingRealtime();
      serviceLocator.registerLazySingleton<OperatorSafetyReviewsCubit>(
        () => OperatorSafetyReviewsCubit(
          getReviews: GetWeatherSafetyReviewsUseCase(safety),
          networkInfo: FakeNetworkInfo(),
          realtime: realtime,
        ),
      );
    });

    testWidgets('the badge counts pending and escalated reviews', (
      tester,
    ) async {
      safety.reviews = [
        review(id: 3),
        review(id: 2, status: WeatherSafetyReviewStatus.escalated),
        review(id: 1, status: WeatherSafetyReviewStatus.acknowledged),
      ];
      final cubit = await _authenticatedCubit();
      addTearDown(cubit.close);

      await _pumpShell(tester, cubit);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('operator-safety-alerts')), findsOneWidget);
      expect(find.byTooltip('Thông báo'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(realtime.starts, 1);
    });

    testWidgets('no badge number is shown when nothing needs attention', (
      tester,
    ) async {
      final cubit = await _authenticatedCubit();
      addTearDown(cubit.close);

      await _pumpShell(tester, cubit);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('operator-safety-alerts')), findsOneWidget);
      expect(find.byType(Badge), findsNothing);
    });

    testWidgets('demo mode never connects or calls the Backend', (
      tester,
    ) async {
      final cubit = await _authenticatedCubit();
      addTearDown(cubit.close);

      await _pumpShell(tester, cubit, isDemoMode: true);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('operator-safety-alerts')), findsNothing);
      expect(find.byTooltip('Thông báo'), findsNothing);
      expect(realtime.starts, 0);
      expect(safety.getReviewsCalls, 0);
    });

    testWidgets('backgrounding stops the connection and resuming refreshes', (
      tester,
    ) async {
      final cubit = await _authenticatedCubit();
      addTearDown(cubit.close);
      await _pumpShell(tester, cubit);
      await tester.pumpAndSettle();
      final before = safety.getReviewsCalls;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(realtime.stops, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(realtime.starts, 2);
      expect(safety.getReviewsCalls, before + 1);
    });

    testWidgets('leaving the shell clears the session data', (tester) async {
      safety.reviews = [review()];
      final cubit = await _authenticatedCubit();
      addTearDown(cubit.close);
      await _pumpShell(tester, cubit);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(
        serviceLocator<OperatorSafetyReviewsCubit>().state.reviews,
        isEmpty,
      );
      expect(realtime.stops, 1);
    });
  });

  testWidgets('operator shell sign-out uses the backend-integrated flow once', (
    tester,
  ) async {
    final repository = _RecordingAuthRepository();
    final cubit = await _authenticatedCubit(repository: repository);
    addTearDown(cubit.close);
    await _pumpShell(tester, cubit);

    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();

    final signOutButton = find.byKey(
      const Key('operator-profile-sign-out-button'),
    );
    await tester.scrollUntilVisible(
      signOutButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(signOutButton);
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

    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();

    expect(find.text('Đổi mật khẩu'), findsOneWidget);
  });

  testWidgets('operator Tours tab offers the create-tour-package entry', (
    tester,
  ) async {
    final cubit = await _authenticatedCubit();
    addTearDown(cubit.close);
    await _pumpShell(tester, cubit);

    await tester.tap(find.text('Tour'));
    await tester.pumpAndSettle();

    expect(find.text('Tạo gói tour mới'), findsOneWidget);
  });

  testWidgets('operator shell sign-out action is disabled while in flight', (
    tester,
  ) async {
    final completer = Completer<void>();
    final repository = _RecordingAuthRepository(logoutCompleter: completer);
    final cubit = await _authenticatedCubit(repository: repository);
    addTearDown(cubit.close);
    await _pumpShell(tester, cubit);

    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();

    final signOutButton = find.byKey(
      const Key('operator-profile-sign-out-button'),
    );
    await tester.scrollUntilVisible(
      signOutButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(signOutButton);
    await tester.pump();

    // Busy state is derived from the approved Cubit marker, not a page flag.
    expect(cubit.state.operation, AuthSessionOperation.signOut);
    expect(tester.widget<ButtonStyleButton>(signOutButton).onPressed, isNull);

    await tester.tap(signOutButton, warnIfMissed: false);
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
    'operator shell uses live metrics while other sections preserve their existing behavior',
    (tester) async {
      final cubit = await _authenticatedCubit();
      addTearDown(cubit.close);
      await _pumpShell(tester, cubit, isDemoMode: false);
      await tester.pumpAndSettle();

      // On Dashboard in production:
      // Hardcoded fake revenue or fake bookings must NOT appear as real data
      expect(find.text('38.500.000 VNĐ'), findsNothing);
      expect(find.text('Nguyễn Văn An'), findsNothing);
      expect(find.text('BK-2026-901'), findsNothing);
      expect(find.text('2 gói'), findsOneWidget);
      expect(find.text('3 đơn'), findsOneWidget);
      expect(find.text('10.000 VNĐ'), findsOneWidget);
      expect(find.text('1 mã'), findsOneWidget);
      expect(find.text('Chờ kết nối API'), findsNothing);

      // The Bookings tab loads only when it is first selected.
      expect(bookings.pageQueries, isEmpty);
      expect(requestedDemoFlags, isEmpty);

      // Navigate to Bookings tab
      await tester.tap(find.text('Đơn đặt'));
      await tester.pumpAndSettle();

      // The live bookings come from the backend repository; there is no pending notice and no fixture.
      expect(bookings.pageQueries, hasLength(1));
      expect(requestedDemoFlags, [false]);
      expect(find.text('BK-20261020-0007'), findsOneWidget);
      expect(find.text('Chưa có đơn đặt tour'), findsNothing);
      expect(find.textContaining('PENDING_BE_INTEGRATION'), findsNothing);
      expect(find.text(OperatorBookingsStringsEn.demoBanner), findsNothing);
      expect(find.text('BK-2026-901'), findsNothing);
      expect(find.text('Nguyễn Văn An'), findsNothing);

      // Navigate to Revenue tab
      await tester.tap(find.text('Tài chính'));
      await tester.pumpAndSettle();

      expect(find.text('Tổng quan tài chính'), findsOneWidget);
      expect(find.text('Quyết toán gần đây'), findsOneWidget);
      expect(find.byKey(const Key('finance-section-revenue')), findsNothing);
      expect(find.text('Bộ lọc'), findsNothing);
      expect(find.textContaining('PENDING_BE_INTEGRATION'), findsNothing);
      expect(find.text('Rút tiền / Payout'), findsNothing);

      // Open Coupons screen from Tour hub
      await tester.tap(find.text('Tour'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('operator-open-coupons-button')));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có mã khuyến mãi'), findsOneWidget);
      expect(find.textContaining('PENDING_BE_INTEGRATION'), findsNothing);
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
      expect(find.text('38.500.000 VNĐ'), findsOneWidget);

      // Navigate to Bookings tab in demo mode
      await tester.tap(find.text('Đơn đặt'));
      await tester.pumpAndSettle();

      expect(find.text(OperatorBookingsStringsEn.demoBanner), findsOneWidget);
      expect(requestedDemoFlags, [true]);
      expect(
        find.text('BK-20260914-0144'),
        findsOneWidget,
      ); // the newest demo booking
      expect(find.textContaining('Dang Quoc Bao'), findsWidgets);
      expect(bookings.pageQueries, isEmpty);
      // The old placeholders are gone: no QR check-in, refund or pickup control in this task.
      expect(find.textContaining('Check-in QR'), findsNothing);
      expect(find.textContaining('hoàn tiền'), findsNothing);

      // Navigate to Revenue tab in demo mode
      await tester.tap(find.text('Tài chính'));
      await tester.pumpAndSettle();

      expect(find.textContaining('DỮ LIỆU DEMO'), findsOneWidget);

      // Open Coupons screen from Tour hub in demo mode
      await tester.tap(find.text('Tour'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('operator-open-coupons-button')));
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
