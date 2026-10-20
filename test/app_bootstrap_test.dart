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

  testWidgets('guest landing screen renders on app bootstrap', (tester) async {
    await tester.pumpWidget(const TripMateApp());
    await tester.pumpAndSettle();

    expect(
      find.text('Hành trình trọn vẹn,\ntrải nghiệm thông minh'),
      findsOneWidget,
    );
    expect(find.text('Tìm tour Đà Nẵng, Hội An, Huế...'), findsOneWidget);
    expect(find.text('Tour du lịch thịnh hành'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);
    expect(find.text('Đăng ký'), findsOneWidget);
    expect(find.text('Demo credentials'), findsNothing);
    expect(find.text('Open demo screen index'), findsNothing);
    expect(find.text('Phone / OTP'), findsNothing);
  });

  testWidgets(
    'guest can navigate to login and return via guest browse action',
    (tester) async {
      await tester.pumpWidget(const TripMateApp());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Đăng nhập').first);
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);

      final guestExploreLink = find.text('Duyệt khám phá không cần đăng nhập');
      await tester.scrollUntilVisible(
        guestExploreLink,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(guestExploreLink);
      await tester.pumpAndSettle();

      expect(
        find.text('Hành trình trọn vẹn,\ntrải nghiệm thông minh'),
        findsOneWidget,
      );
    },
  );
}
