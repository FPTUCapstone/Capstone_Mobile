import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trip_mate_mobile/app/app.dart';
import 'package:trip_mate_mobile/app/config/app_config.dart';
import 'package:trip_mate_mobile/app/config/environment.dart';
import 'package:trip_mate_mobile/core/di/service_locator.dart';
import 'package:trip_mate_mobile/features/auth/presentation/cubit/auth_session_cubit.dart';

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
    await serviceLocator.unregister<AuthSessionCubit>();
    serviceLocator.registerFactory<AuthSessionCubit>(AuthSessionCubit.new);
  });

  tearDown(() => serviceLocator.reset());

  testWidgets('sign-in screen renders on app bootstrap', (tester) async {
    await tester.pumpWidget(const TripMateApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Demo credentials'), findsNothing);
    expect(find.text('Open demo screen index'), findsNothing);
    expect(find.text('Phone / OTP'), findsNothing);
  });

  testWidgets('guest can enter public POI exploration without signing in', (
    tester,
  ) async {
    await tester.pumpWidget(const TripMateApp());
    await tester.pumpAndSettle();

    final guestExploreLink = find.text('Duyệt khám phá không cần đăng nhập');
    await tester.scrollUntilVisible(
      guestExploreLink,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(TextButton, 'Duyệt khám phá không cần đăng nhập'),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Khám phá miền Trung'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
  });
}
