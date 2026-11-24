import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/app/router/app_router.dart';
import 'package:trip_mate_mobile/app/router/app_routes.dart';
import 'package:trip_mate_mobile/core/constants/app_constants.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/core/storage/secure_storage_service.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/data/repositories/demo_operator_finance_repository.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/cubit/operator_settlement_history_cubit.dart';
import 'package:trip_mate_mobile/features/operator_finance/presentation/pages/operator_settlement_history_page.dart';

class _MemoryStorage implements SecureStorageService {
  final values = <String, String>{
    AppConstants.accessTokenKey: 'access',
    AppConstants.refreshTokenKey: 'refresh',
    AppConstants.sessionRoleKey: 'tourOperator',
    AppConstants.keepSignedInKey: 'true',
    'session_application_status': 'approved',
  };
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    values.clear();
  }
}

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

  for (final item in [
    (suffix: '', debug: true, demo: false),
    (suffix: '?demo=true', debug: true, demo: true),
    (suffix: '?demo=true', debug: false, demo: false),
  ]) {
    testWidgets(
      'settlement history ${item.suffix} debug=${item.debug} uses its own read-only page',
      (tester) async {
        final demoArgs = <bool>[];
        await serviceLocator.unregister<OperatorSettlementHistoryCubit>();
        serviceLocator
            .registerFactoryParam<OperatorSettlementHistoryCubit, bool, void>((
              demo,
              _,
            ) {
              demoArgs.add(demo);
              return OperatorSettlementHistoryCubit(
                const DemoOperatorFinanceRepository(),
              );
            });
        final session = AuthSessionCubit(null, _MemoryStorage());
        await session.restoreSession();
        addTearDown(session.close);
        final router = createAppRouter(session, isDebug: item.debug);
        addTearDown(router.dispose);
        router.go('${AppRoutes.operatorSettlementHistory}${item.suffix}');
        await tester.pumpWidget(
          BlocProvider<AuthSessionCubit>.value(
            value: session,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(OperatorSettlementHistoryPage), findsOneWidget);
        expect(
          tester
              .widget<OperatorSettlementHistoryPage>(
                find.byType(OperatorSettlementHistoryPage),
              )
              .isDemoMode,
          item.demo,
        );
        expect(demoArgs, [item.demo]);
        expect(find.text('Rút tiền'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
