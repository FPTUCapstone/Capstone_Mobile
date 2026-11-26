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
import 'package:trip_mate_mobile/features/poi/presentation/pages/explore_poi_page.dart';
import 'package:trip_mate_mobile/features/tour_search/presentation/pages/tour_search_page.dart';
import 'package:trip_mate_mobile/features/traveler/presentation/pages/traveler_shell_page.dart';
import 'package:trip_mate_mobile/shared/widgets/app_sliding_bottom_nav.dart';

class _MemoryStorage implements SecureStorageService {
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
  tearDown(serviceLocator.reset);

  for (final path in [AppRoutes.explore, AppRoutes.tourSearch]) {
    for (final traveler in [true, false]) {
      testWidgets(
        '$path ${traveler ? 'traveler keeps shell menu' : 'guest remains standalone'}',
        (tester) async {
          final session = AuthSessionCubit(
            null,
            _MemoryStorage(
              traveler
                  ? {
                      AppConstants.accessTokenKey: 'access',
                      AppConstants.refreshTokenKey: 'refresh',
                      AppConstants.sessionRoleKey: 'traveler',
                      AppConstants.keepSignedInKey: 'true',
                    }
                  : {},
            ),
          );
          await session.restoreSession();
          final router = createAppRouter(session);
          addTearDown(router.dispose);
          addTearDown(session.close);
          router.go(path);
          await tester.pumpWidget(
            BlocProvider<AuthSessionCubit>.value(
              value: session,
              child: MaterialApp.router(routerConfig: router),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            find.byType(TravelerShellPage),
            traveler ? findsOneWidget : findsNothing,
          );
          expect(
            find.byType(AppSlidingBottomNav),
            traveler ? findsOneWidget : findsNothing,
          );
          if (path == AppRoutes.tourSearch) {
            expect(find.byType(TourSearchPage), findsOneWidget);
            expect(
              find.byIcon(Icons.arrow_back),
              traveler ? findsNothing : findsOneWidget,
            );
          } else {
            expect(find.byType(ExplorePoiPage), findsOneWidget);
          }
          if (traveler) {
            await tester.tap(find.byIcon(Icons.person_outline));
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.text('Hồ sơ du khách'), findsOneWidget);
            expect(find.byType(AppSlidingBottomNav), findsOneWidget);
          }
        },
      );
    }
  }
}
