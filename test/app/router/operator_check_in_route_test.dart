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

  test('Regression: original buggy logic vs corrected logic', () {
    final uriWithDemo = Uri.parse('/operator/check-in?demo=true');
    final uriWithoutDemo = Uri.parse('/operator/check-in');
    final uriWithDemoFalse = Uri.parse('/operator/check-in?demo=false');

    bool originalBuggy(Uri uri) => uri.queryParameters['demo'] == 'true';

    expect(originalBuggy(uriWithDemo), isTrue);
    expect(resolveOperatorCheckInDemo(uriWithDemo, isDebug: false), isFalse);
    expect(resolveOperatorCheckInDemo(uriWithoutDemo, isDebug: false), isFalse);
    expect(
      resolveOperatorCheckInDemo(uriWithDemoFalse, isDebug: false),
      isFalse,
    );
    expect(resolveOperatorCheckInDemo(uriWithDemo, isDebug: true), isTrue);
    expect(resolveOperatorCheckInDemo(uriWithoutDemo, isDebug: true), isFalse);
  });

  test('DI resolution: demo flag strictly controls repository instance', () {
    final demoRepo = serviceLocator<OperatorCheckInRepository>(param1: true);
    final liveRepo = serviceLocator<OperatorCheckInRepository>(param1: false);

    expect(demoRepo, isA<DemoOperatorCheckInRepository>());
    expect(liveRepo, isA<OperatorCheckInRepositoryImpl>());
  });

  test('Release + Backend unavailable emits error', () async {
    final liveCubit = serviceLocator<OperatorCheckInCubit>(param1: false);
    addTearDown(liveCubit.close);

    expect(liveCubit.state, isA<OperatorCheckInInitial>());
    await liveCubit.loadInitial();
    expect(liveCubit.state, isA<OperatorCheckInError>());

    final demoCubit = serviceLocator<OperatorCheckInCubit>(param1: true);
    addTearDown(demoCubit.close);

    await demoCubit.loadInitial();
    expect(demoCubit.state, isA<OperatorCheckInLoaded>());
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
    final demoCubit = serviceLocator<OperatorCheckInCubit>(param1: true);
    addTearDown(demoCubit.close);

    await demoCubit.loadInitial();
    expect(demoCubit.state, isA<OperatorCheckInLoaded>());

    await demoCubit.submitScan(bookingCode: 'TM-20261030-001');
    final demoState = demoCubit.state as OperatorCheckInLoaded;
    expect(demoState.lastResult, isNotNull);

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
    await pumpAt(
      tester,
      '${AppRoutes.operatorCheckIn}?demo=true',
      isDebug: false,
    );
    expect(find.byType(OperatorCheckInPage), findsOneWidget);
    expect(requestedDemoFlags, [false]);
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
    await pumpAt(
      tester,
      '${AppRoutes.operatorCheckIn}?demo=true',
      isDebug: true,
    );
    expect(requestedDemoFlags.last, isTrue);

    await pumpAt(tester, AppRoutes.operatorCheckIn, isDebug: true);
    expect(requestedDemoFlags.last, isFalse);

    await pumpAt(
      tester,
      '${AppRoutes.operatorCheckIn}?demo=true',
      isDebug: false,
    );
    expect(requestedDemoFlags.last, isFalse);

    expect(requestedDemoFlags, [true, false, false]);
  });
}
