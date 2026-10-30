import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/operator_check_in/data/repositories/demo_operator_check_in_repository.dart';
import 'package:trip_mate_mobile/features/operator_check_in/data/repositories/operator_check_in_repository_impl.dart';
import 'package:trip_mate_mobile/features/operator_check_in/domain/repositories/operator_check_in_repository.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_cubit.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/cubit/operator_check_in_state.dart';
import 'package:trip_mate_mobile/features/operator_check_in/presentation/pages/operator_check_in_page.dart';

final class _MemoryStorage implements SecureStorageService {
  _MemoryStorage(this._data);

  final Map<String, String> _data;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> deleteAll() async => _data.clear();

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;
}

void main() {
  late List<bool> requestedDemoFlags;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await serviceLocator.reset();
    await configureDependencies(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
    );
    requestedDemoFlags = [];
    serviceLocator
      ..unregister<OperatorCheckInCubit>()
      ..registerFactoryParam<OperatorCheckInCubit, bool, void>((isDemo, _) {
        requestedDemoFlags.add(isDemo);
        return OperatorCheckInCubit(
          getTodayDepartures: serviceLocator(param1: isDemo),
          getDepartureProgress: serviceLocator(param1: isDemo),
          scanCheckIn: serviceLocator(param1: isDemo),
        );
      });
  });

  tearDown(() => serviceLocator.reset());

  Future<AuthSessionCubit> createApprovedOperatorSession() async {
    final session = AuthSessionCubit(
      null,
      _MemoryStorage({
        AppConstants.accessTokenKey: 'valid-test-access-token',
        AppConstants.refreshTokenKey: 'valid-test-refresh-token',
        AppConstants.sessionRoleKey: 'tourOperator',
        AppConstants.keepSignedInKey: 'true',
        'session_application_status': 'approved',
      }),
    );
    await session.restoreSession();
    return session;
  }

  Future<GoRouter> pumpAt(
    WidgetTester tester,
    String location, {
    bool isDebug = true,
  }) async {
    final session = await createApprovedOperatorSession();
    addTearDown(session.close);

    final router = createAppRouter(session, isDebug: isDebug);
    addTearDown(router.dispose);

    router.go(location);
    await tester.pumpWidget(
      BlocProvider<AuthSessionCubit>.value(
        value: session,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return router;
  }

  group('TM-89 Phase 6D: Operator Check-In Demo Mode Release Safety', () {
    test('Regression: original buggy logic vs corrected logic', () {
      final uriWithDemo = Uri.parse('/operator/check-in?demo=true');
      final uriWithoutDemo = Uri.parse('/operator/check-in');
      final uriWithDemoFalse = Uri.parse('/operator/check-in?demo=false');

      // Original buggy implementation:
      // final isDemo = state.uri.queryParameters['demo'] == 'true';
      bool originalBuggyLogic(Uri uri) => uri.queryParameters['demo'] == 'true';

      // In a release build (isDebug == false):
      // The original logic INCORRECTLY evaluated to true for ?demo=true,
      // which exposed demo mock fixtures in a production release.
      expect(
        originalBuggyLogic(uriWithDemo),
        isTrue,
        reason: 'Original bug: demo=true activated mock fixtures',
      );

      // The corrected logic strictly requires isDebug (kDebugMode):
      expect(
        resolveOperatorCheckInDemo(uriWithDemo, isDebug: false),
        isFalse,
        reason: 'Release build with demo=true must not be demo',
      );

      expect(
        resolveOperatorCheckInDemo(uriWithoutDemo, isDebug: false),
        isFalse,
        reason: 'Release build without demo query param routes to live Backend',
      );

      expect(
        resolveOperatorCheckInDemo(uriWithDemoFalse, isDebug: false),
        isFalse,
        reason: 'Release build with demo=false routes to live Backend',
      );

      // In a debug build (isDebug == true):
      expect(
        resolveOperatorCheckInDemo(uriWithDemo, isDebug: true),
        isTrue,
        reason: 'Debug build with demo=true permits demo mode for staging/QA',
      );

      expect(
        resolveOperatorCheckInDemo(uriWithoutDemo, isDebug: true),
        isFalse,
        reason: 'Debug build without demo param routes to live Backend',
      );
    });

    test('DI resolution: demo flag strictly controls repository instance', () {
      final demoRepo = serviceLocator<OperatorCheckInRepository>(param1: true);
      final liveRepo = serviceLocator<OperatorCheckInRepository>(param1: false);

      expect(demoRepo, isA<DemoOperatorCheckInRepository>());
      expect(liveRepo, isA<OperatorCheckInRepositoryImpl>());
      expect(liveRepo, isNot(isA<DemoOperatorCheckInRepository>()));
    });

    test('Release + Backend unavailable emits error', () async {
      // Live Cubit configured with unreachable test host
      final liveCubit = serviceLocator<OperatorCheckInCubit>(param1: false);
      addTearDown(liveCubit.close);

      expect(liveCubit.state, isA<OperatorCheckInInitial>());

      // Loading against unreachable host emits OperatorCheckInError
      await liveCubit.loadInitial();

      expect(
        liveCubit.state,
        isA<OperatorCheckInError>(),
        reason: 'Live cubit emits error when backend is down',
      );
      final errorState = liveCubit.state as OperatorCheckInError;
      expect(errorState.message, isNotEmpty);

      // In contrast, demo Cubit loads sample fixtures
      final demoCubit = serviceLocator<OperatorCheckInCubit>(param1: true);
      addTearDown(demoCubit.close);

      await demoCubit.loadInitial();
      expect(demoCubit.state, isA<OperatorCheckInLoaded>());
      final loadedState = demoCubit.state as OperatorCheckInLoaded;
      expect(loadedState.departures, isNotEmpty);
    });

    test('Repeated DI requests has no mode leakage between cubits', () async {
      final cubit1 = serviceLocator<OperatorCheckInCubit>(param1: true);
      final cubit2 = serviceLocator<OperatorCheckInCubit>(param1: false);
      final cubit3 = serviceLocator<OperatorCheckInCubit>(param1: true);
      addTearDown(cubit1.close);
      addTearDown(cubit2.close);
      addTearDown(cubit3.close);

      await cubit1.loadInitial();
      await cubit2.loadInitial();
      await cubit3.loadInitial();

      expect(cubit1.state, isA<OperatorCheckInLoaded>());
      expect(cubit2.state, isA<OperatorCheckInError>());
      expect(cubit3.state, isA<OperatorCheckInLoaded>());
    });

    test('QR and manual check-in preserved in both modes', () async {
      // 1. Demo mode check-in functionality
      final demoCubit = serviceLocator<OperatorCheckInCubit>(param1: true);
      addTearDown(demoCubit.close);

      await demoCubit.loadInitial();
      expect(demoCubit.state, isA<OperatorCheckInLoaded>());

      // Manual check-in via booking code in demo mode
      await demoCubit.submitScan(bookingCode: 'TM-20261030-001');
      final demoState = demoCubit.state as OperatorCheckInLoaded;
      expect(demoState.lastResult, isNotNull);
      expect(demoState.lastResult!.ticketCode, isNotEmpty);
      expect(demoState.recentScans, isNotEmpty);

      // 2. Live mode check-in fails closed when backend unreachable
      final liveCubit = serviceLocator<OperatorCheckInCubit>(param1: false);
      addTearDown(liveCubit.close);

      await liveCubit.loadInitial();
      expect(liveCubit.state, isA<OperatorCheckInError>());
    });

    testWidgets('Debug + demo=true uses demo fixtures', (tester) async {
      await pumpAt(
        tester,
        '${AppRoutes.operatorCheckIn}?demo=true',
        isDebug: true,
      );

      expect(find.byType(OperatorCheckInPage), findsOneWidget);
      expect(requestedDemoFlags, [true]);
    });

    testWidgets('Debug without demo param is live', (tester) async {
      await pumpAt(tester, AppRoutes.operatorCheckIn, isDebug: true);

      expect(find.byType(OperatorCheckInPage), findsOneWidget);
      expect(requestedDemoFlags, [false]);
    });

    testWidgets('Release + demo=true is strictly live', (tester) async {
      // isDebug: false simulates a production release build
      await pumpAt(
        tester,
        '${AppRoutes.operatorCheckIn}?demo=true',
        isDebug: false,
      );

      expect(find.byType(OperatorCheckInPage), findsOneWidget);
      expect(
        requestedDemoFlags,
        [false],
        reason: 'Release builds must NEVER pass isDemo: true to the Cubit',
      );
    });

    testWidgets('Release + demo=false is live', (tester) async {
      await pumpAt(
        tester,
        '${AppRoutes.operatorCheckIn}?demo=false',
        isDebug: false,
      );

      expect(find.byType(OperatorCheckInPage), findsOneWidget);
      expect(requestedDemoFlags, [false]);
    });

    testWidgets('Repeated navigation has no leakage', (tester) async {
      // 1. Route with demo=true in debug build
      await pumpAt(
        tester,
        '${AppRoutes.operatorCheckIn}?demo=true',
        isDebug: true,
      );
      expect(requestedDemoFlags.last, isTrue);

      // 2. Route with no demo param
      await pumpAt(tester, AppRoutes.operatorCheckIn, isDebug: true);
      expect(requestedDemoFlags.last, isFalse);

      // 3. Route with demo=true in release build
      await pumpAt(
        tester,
        '${AppRoutes.operatorCheckIn}?demo=true',
        isDebug: false,
      );
      expect(requestedDemoFlags.last, isFalse);

      expect(requestedDemoFlags, [true, false, false]);
    });
  });
}
