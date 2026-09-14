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
}
