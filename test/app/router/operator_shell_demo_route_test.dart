import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/tour_operator/presentation/pages/operator_shell_page.dart';

final class _MemoryStorage implements SecureStorageService {
  _MemoryStorage(this.values);

  final Map<String, String> values;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// The `/operator` workspace serves demo fixtures only for an explicit `demo=true` in a debug build; the route
/// reads `kDebugMode && demo=true` like every other demo route, so a release build ignores the flag. `flutter
/// test` always runs in debug mode, so the release half of that expression cannot be exercised here.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await serviceLocator.reset();
    await configureDependencies(
      config: AppConfig(
        environment: Environment.development,
        apiBaseUrl: Uri.parse('https://api.test.invalid'),
      ),
    );
  });

  tearDown(() => serviceLocator.reset());

  Future<bool> shellIsDemo(WidgetTester tester, String location) async {
    final session = AuthSessionCubit(
      null,
      _MemoryStorage({
        AppConstants.accessTokenKey: 'access',
        AppConstants.refreshTokenKey: 'refresh',
        AppConstants.sessionRoleKey: 'tourOperator',
        AppConstants.keepSignedInKey: 'true',
        'session_application_status': 'approved',
      }),
    );
    await session.restoreSession();
    final router = createAppRouter(session);
    addTearDown(router.dispose);
    addTearDown(session.close);
    router.go(location);
    await tester.pumpWidget(
      BlocProvider<AuthSessionCubit>.value(
        value: session,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return tester
        .widget<OperatorShellPage>(find.byType(OperatorShellPage))
        .isDemoMode;
  }

  testWidgets('/operator is live unless the demo flag is explicit', (
    tester,
  ) async {
    expect(await shellIsDemo(tester, '/operator'), isFalse);
  });

  testWidgets('/operator?demo=false and any other value stay live', (
    tester,
  ) async {
    expect(await shellIsDemo(tester, '/operator?demo=false'), isFalse);
  });

  testWidgets('/operator?demo=true is demo in a debug build', (tester) async {
    expect(await shellIsDemo(tester, '/operator?demo=true'), isTrue);
  });
}
